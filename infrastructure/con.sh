#!/bin/bash
apt-get update -y
apt-get install -y docker.io git curl conntrack
usermod -aG docker ubuntu

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install kubectl /usr/local/bin/kubectl

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

sudo -u ubuntu -H minikube start --driver=docker --cni=calico --cpus=2 --memory=3072
sudo -u ubuntu -H minikube addons enable ingress
sudo -u ubuntu -H minikube addons enable metrics-server