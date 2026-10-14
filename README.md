# AWS IaC + Kubernetes Multi-Tier Microservices

A three-tier web application (Nginx, Flask, MySQL) deployed on a Kubernetes cluster that runs on AWS infrastructure created entirely with **Terraform**.

The project covers the full path from an empty AWS account to a running application: network, server, cluster, deployment, storage, routing, autoscaling and network security.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Tech Stack](#tech-stack)
3. [Repository Structure](#repository-structure)
4. [What Terraform Creates](#what-terraform-creates)
5. [Kubernetes Components](#kubernetes-components)
6. [Prerequisites](#prerequisites)
7. [Deployment Guide](#deployment-guide)
8. [Verification and Testing](#verification-and-testing)
9. [Network Policies](#network-policies)
10. [Challenges and Lessons Learned](#challenges-and-lessons-learned)
11. [Limitations and Future Improvements](#limitations-and-future-improvements)
12. [Cleanup](#cleanup)

---

## Architecture

```
                 Terraform
                    |
                    v
   AWS (eu-west-2): VPC -> Public Subnet -> EC2 (Ubuntu 24.04)
                                                |
                                          Minikube (Docker driver + Calico)
                                                |
 User -> Ingress (NGINX) -> frontend-svc -> Nginx pods
                                                |  /api
                                                v
                                          backend-svc -> Flask pods
                                                |  port 3306
                                                v
                                           db-svc -> MySQL pod -> PersistentVolumeClaim
```

| Tier | Technology | Role |
|---|---|---|
| Frontend | Nginx | Serves the static page and proxies `/api` to the backend |
| Backend | Python Flask | API with `/api/health` and `/api/data` endpoints |
| Database | MySQL 8.0 | Stores data on a persistent volume |

---

## Tech Stack

- **Infrastructure as Code:** Terraform (AWS provider)
- **Cloud:** AWS (VPC, EC2, security groups)
- **Orchestration:** Kubernetes via Minikube (Docker driver, Calico CNI)
- **Add-ons:** NGINX Ingress controller, metrics-server
- **Application:** Nginx, Python Flask, MySQL 8.0
- **Tools:** kubectl, Git, GitHub

---

## Repository Structure

```
.
├── infrastructure/          # Terraform code
│   ├── providers.tf         # AWS provider and version
│   ├── variables.tf         # Inputs (region, IP, key pair, instance type)
│   ├── main.tf              # VPC, subnet, gateway, routes, security group, EC2
│   ├── output.tf            # Public IP and SSH command
│   └── <con.sh>     # user_data: installs Docker, kubectl, Minikube
├── database/                # MySQL ConfigMap, Deployment, Service, PVC
├── backend/                 # Flask ConfigMap, Deployment, Service, HPA
├── frontend/                # Nginx ConfigMaps, Deployment, Service, Ingress, HPA
├── networkPolicy/           # Policies for frontend, backend, database
└── README.md
```

---

## What Terraform Creates

| Resource | Purpose |
|---|---|
| `aws_vpc` | Isolated private network |
| `aws_subnet` | Public subnet that hosts the instance |
| `aws_internet_gateway` | Gives the VPC internet access |
| `aws_route_table` and association | Routes the subnet's traffic to the gateway |
| `aws_security_group` | Allows SSH and the app port only from the owner's IP |
| `data.aws_ami` | Looks up the latest official Ubuntu 24.04 image |
| `aws_instance` | EC2 instance with a 30 GB disk and a startup script |

The startup script (`con.sh`) installs Docker, kubectl and Minikube, then starts the cluster with Calico and enables the `ingress` and `metrics-server` add-ons, so the instance is ready for deployment as soon as it boots.

Terraform works out the creation order from the references between resources (for example, the subnet refers to the VPC ID), so the order never has to be written by hand.

---

## Kubernetes Components

| Component | Files | Description |
|---|---|---|
| Namespace | created with `kubectl` | All resources live in `multi-app` |
| ConfigMaps | `cm-for-*.yaml`, `frontend-nginx-traffic-config.yaml` | App settings and the Nginx routing config |
| Secret | created with `kubectl` | MySQL passwords, never stored in Git |
| Deployments and Services | `*-deploy.yaml`, `*-svc.yaml` | One per tier |
| **PersistentVolumeClaim** | `database/pvc-db.yml` | Keeps MySQL data across pod restarts (replaces a temporary `emptyDir`) |
| **Ingress** | `frontend/frontend-ingress.yaml` | Routes outside traffic to `frontend-svc` |
| **HPA** | `hpa-frontend.yml`, `hpa-backend.yml` | Scales pods on CPU usage |
| NetworkPolicies | `networkPolicy/` | Restricts traffic between tiers |

Notes:

- The database Deployment uses the `Recreate` strategy, because a `ReadWriteOnce` volume can attach to only one pod at a time.
- The frontend and backend containers define CPU **requests**. The HPA needs them to calculate utilization.

---

## Prerequisites

On your laptop:

- [Terraform](https://developer.hashicorp.com/terraform/install) installed (`terraform -version`)
- [AWS CLI](https://aws.amazon.com/cli/) configured with an IAM user (`aws configure`)
- An EC2 **key pair** created in the same region as the deployment, plus its `.pem` file
- Your public IP (`curl https://checkip.amazonaws.com`)

---

## Deployment Guide

### 1. Create the infrastructure

```bash
cd infrastructure
```

Create a `terraform.tfvars` file (it is ignored by Git):

```hcl
my_ip    = "<your-public-ip>/32"
key_pair = "<your-key-pair-name>"   # name in AWS, without .pem
```

Then run:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform prints the instance's public IP and an SSH command.

### 2. Connect to the instance

Wait about 5 minutes for the startup script to finish, then:

```bash
ssh -i ~/.ssh/<key_name>.pem ubuntu@<public-ip>
minikube status
kubectl get nodes
```

### 3. Clone the repository

```bash
git clone https://github.com/MohammadAhmadPiprani/aws-iac-k8s-microservices.git
cd aws-iac-k8s-microservices
```

### 4. Create the namespace and secret

Use placeholder values below and choose your own passwords. Never commit real ones.

```bash
kubectl create namespace multi-app
kubectl create secret generic database-secret --from-literal=MYSQL_ROOT_PASSWORD=<root-password> --from-literal=MYSQL_PASSWORD=<user-password> -n multi-app
```

### 5. Deploy the application

```bash
kubectl apply -f database/
kubectl apply -f backend/
kubectl apply -f frontend/
kubectl get pods -n multi-app -w
```

When all pods are `Running`, apply the network policies:

```bash
kubectl apply -f networkPolicy/
```

### 6. Open the application

`kubectl port-forward` exposes the Ingress controller on the instance. This is for demonstration only.

```bash
kubectl port-forward --address 0.0.0.0 -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

Open `http://<public-ip>:8080` in a browser (the security group allows port 8080 from your IP).

---

## Verification and Testing

### Application

```bash
curl http://localhost:8080/api/health
curl http://localhost:8080/api/data
```

`/api/health` should report the backend as healthy. `/api/data` returns the MySQL version, which confirms that the frontend, backend and database are all connected.

### Resources

```bash
kubectl get pods,svc,pvc,ingress,hpa,networkpolicy -n multi-app
```

- The PVC should show `Bound`.
- The HPA TARGETS column should show percentages, not `<unknown>`.

### Persistence test

1. Open MySQL and insert a row:
   ```bash
   kubectl exec -it deploy/db-deploy -n multi-app -- mysql -u root -p
   ```
2. Delete the database pod:
   ```bash
   kubectl delete pod -l app=db -n multi-app
   ```
3. When the new pod is running, query the table again. The row should still be there.

### Autoscaling test

Generate load from a frontend pod (allowed by the network policies) and watch the HPA:

```bash
kubectl get hpa -n multi-app -w
```

```bash
kubectl exec -it deploy/frontend-deploy -n multi-app -- sh
# inside the container:
for i in 1 2 3 4 5 6 7 8; do
  while true; do wget -q -O- http://backend-svc:5000/api/data > /dev/null; done &
done
```

CPU utilization should rise and the replica count should increase. After the load stops, replicas scale back down after a cooldown of a few minutes.


---

## Network Policies

Each tier can talk only to the tier next to it:

| Policy | Ingress (who can connect in) | Egress (where it can connect out) |
|---|---|---|
| Frontend | Anyone (public traffic) | Backend on port 5000, CoreDNS on port 53 |
| Backend | Frontend only, port 5000 | Database on port 3306, CoreDNS on port 53, internet on ports 80 and 443 |
| Database | Backend only, port 3306 | None required |

Every tier needs egress to CoreDNS (UDP and TCP port 53). DNS resolves a service name such as `backend-svc` to an IP address, and without that rule the name lookup fails even though the connection rule itself is correct.

The backend's internet access exists only because it runs `pip install` at startup. Building a custom image with the dependencies preinstalled would allow that rule to be removed.

Policies are enforced because Minikube runs with the Calico CNI (`--cni=calico`).


---

## Limitations and Future Improvements

- **Single node:** Minikube on one EC2 instance is a single point of failure. Elasticity comes from the HPAs and resilience from replicas, self-healing pods and persistent storage, but this is not full high availability.
- **Port-forwarding** is used only to reach the app for demonstration. In production, the Ingress controller would sit behind a cloud load balancer with DNS and HTTPS.
- **Backend image:** the backend installs packages at startup. A custom image would start faster and remove the need for internet access.
- **Secrets:** use a secrets manager instead of command-line secrets.



The same Kubernetes manifests should work on EKS with little change.

---

## Cleanup

To avoid AWS charges, destroy everything when finished:

```bash
cd infrastructure
terraform destroy
```

The key pair was created in the AWS console, so Terraform does not delete it.

---

## Security Notes

- No passwords, access keys or `.pem` files are committed.
- `.gitignore` excludes `.terraform/`, `*.tfstate`, `*.tfvars`, `*.pem` and `*.swp`.
- The security group restricts SSH and the app port to a single IP.
- Restrict the IAM user's permissions after testing, and delete access keys you no longer use.

---

## Author

**Muhammad Ahmad Piprani**

