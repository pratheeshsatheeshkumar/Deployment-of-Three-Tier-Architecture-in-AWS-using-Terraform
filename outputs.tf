
output "bastion_access" {
  value = "ssh -i mykey ec2-user@${aws_instance.bastion.public_ip}"
}
output "frontend_access" {
  value = "ssh -i mykey ec2-user@${aws_instance.frontend.private_ip}"
}

output "backend_access" {
  value = "ssh -i mykey ec2-user@${aws_instance.backend.private_ip}"
}    