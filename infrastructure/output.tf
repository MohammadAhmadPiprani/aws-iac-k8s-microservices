output "instance_ip" {
  value = aws_instance.ec2.public_ip
}


output "ssh_command" {
  value = "ssh -i london_kp ubuntu@${aws_instance.ec2.public_ip}"
}
