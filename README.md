# Deployment of Three Tier Architecture in AWS using Terraform.

![](https://miro.medium.com/max/1400/1*yTTpNBhilzdRpCmPjHAbIQ.png)

Diagram : 1a

This project's goal is to deploy a WordPress website in a Three Tier Architecture. Only front-end server has http access from the Internet. The back-end is installed with MariaDB server and only the front-end server can access the back-end through its private hosted zone. a Bastion server is used to provide ssh access to front-end and back-end servers.


### **Terraform File Hierarchy used in this project.**

I’m giving a project-specific explanation of the file hierarchy here.  
The idea of modules is not used in this project, hence it is not discussed.

![](https://miro.medium.com/max/1400/1*H9rxUSZuyWA_wxxAQ63Xdw.png)

Diagram 1b.

In the base directory, you have to create multiple **.tf** files to avoid the monolithic nature of the code. Although a single ***.tf** file can do the job, best practice is to divide them as per their contents. This is not a mandatory classification and the naming of the .tf files are flexible. But, Here I am following the industry standard. I would suggest you to follow the same instead of code everything in single file.

> **main.tf**

It contains the Resources and Logic to be implemented by Terraform., which consists of the main set of configurations.
```sh
$ mkdir workdesk  
$ cd workdesk/  
$ touch ./main.tf variables.tf outputs.tf datasource.tf provider.tf  
$ ls  
datasource.tf  main.tf  outputs.tf  provider.tf  variables.tf
```
> **provider.tf**

The following code is inside **provider.tf** file that I uses to set up AWS as provider and user account authentication keys. All the variables are declared inside **variables.tf** file, which is exhibited below.
```sh
/*==== Provider ======*/  
/* Setting up of provider name and associated authentication */  
  
provider "aws" {  
  
  region     = var.region  
  access_key = var.access_key   
  secret_key = var.secret_key  
  
  default_tags {  
    tags = local.common_tags  
  }  
}
```
default_tags that are required to assign to all the resources are inside locals section of **variables.tf** file.

> **variables.tf**

The variables used in this project are declared in the file **variable.tf** and all these variables and locals are used in the **main.tf** file. Each input variable accepted by a module must be declared using a `variable` block:
```sh
  
/*==== Variable declerations ======*/

variable "project" {

 default     = "swiggy"  
  description = "Name of the project"  
}

variable "instance_type" {}

variable "instance_ami" {}

variable "cidr_vpc" {}

variable "environment" {}

variable "region" {

 default     = "ap-south-1"  
  description = "Region: Mumbai"  
}

variable "access_key" {

 default     = "XXXXXXXXXXXXXX"  
  description = "access key of the provider"  
}

variable "secret_key" {

 default     = "YYYYYYYYYYYYYY"  
  description = "secret key of the provider"  
}

variable "owner" {

 default = "pratheesh"  
}

variable "application" {

 default = "food-order"  
}

variable "public_domain" {  
    
  default = "pratheeshsatheeshkumar.tech"  
}

variable "private_domain" {  
    
  default = "pratheeshsatheeshkumar.local"  
}  

locals {  
  common_tags = {  
    project     = var.project  
    environment = var.environment  
    owner       = var.owner  
    application = var.application  
  }  
}  

locals {  
  subnets = length(data.aws_availability_zones.available_azs.names)  
}
```
> **datasource.tf**
```sh
/*==== Gatthering of availability zones in the present region from datasource ======*/  
  
data "aws_availability_zones" "available_azs" {  
  state = "available"  
}  
data "aws_route53_zone" "selected" {  
  name         = "pratheeshsatheeshkumar.tech."  
  private_zone = false  
}
```
Terraform use the data sources to access information defined outside of Terraform, defined by some other Terraform configuration, or modified by functions. Here, You have to gather the availability zones in the region defined in the variables.tf.

Similarly, data.aws_route53_zone.selected will provide the hosted zone id form the given domain name.

> **outputs.tf**
```sh
output "bastion_access" {  
  value = "ssh -i mykey ec2-user@${aws_instance.bastion.public_ip}"  
}  
output "frontend_access" {  
  value = "ssh -i mykey ec2-user@${aws_instance.frontend.private_ip}"  
}  
  
output "backend_access" {  
  value = "ssh -i mykey ec2-user@${aws_instance.backend.private_ip}"  
} 
```
Output values make information about your infrastructure available on the command line, and can expose information for other Terraform configurations to use. Output values are similar to return values in programming languages. Here, We have used the same to print ssh access commands with respective ip addresses to all three servers in our project.

> **terraform.tfstate**

Terraform keeps track of the resources it creates in a state file.  
Terraform can then determine which resources are under its control and when to update and destroy them. The terraform state file is named terraform.tfstate by default and is stored in the same directory where Terraform is run. It is created following the execution of terraform apply.  
The actual content of this file is a JSON-formatted mapping of the configuration’s resources and those that exist in your infrastructure.  
When Terraform is run, it can use this mapping to compare infrastructure to code and make any necessary adjustments.

The `terraform state` command can be used to perform advanced state management.

# Relationship diagram of servers with their corresponding security groups.

Only front-end server is available for the public http/https access. Moreover, the back-end server is acting as a database server and there is no public access available. Hence, back-end server is in a private subnet.

![](https://miro.medium.com/max/1400/1*i0VCmMPZQCFqPF3nghFQIw.png)

Diagram :1c

SSH from any IP address is permitted to the bastion server via the bastion security group. is no direct ssh access to the front-end or back-end servers. Instead, security groups are configured so that rules exist to access the front-end from the bastion security group, while also allowing access to the back-end from the front-end via ports 22 and 3306.

# **Activities to be done in AWS to create the infra described in the diagram 1a.**

![](https://miro.medium.com/max/1400/1*idJk6wEq9xrbcw5d8eujrg.png)

**_Step 1: Create a VPC: You have to provide cidr_block as input.(for eg. 172.16.0.0/16). Don’t forget to enable dns hostname._**
```sh
#main.tf  
/*==== vpc ======*/  
/*create vpc in the cidr "172.16.0.0/16" */  
  
resource "aws_vpc" "vpc" {  
  cidr_block           = var.cidr_vpc  
  enable_dns_hostnames = true  
  enable_dns_support   = true  
  instance_tenancy     = "default"  
  tags = {  
    Name = "${var.project}-${var.environment}"  
  }  
}
```
**_Step 2: Create internet gateway for the public subnets and attach with vpc._**
```sh
/*==== IGW ======*/  
/* Create internet gateway for the public subnets and attach with vpc */  
  
resource "aws_internet_gateway" "igw" {  
  vpc_id = aws_vpc.vpc.id  
  
  tags = {  
    Name = "${var.project}-${var.environment}"  
  }  
}
```
**_Step 3: Creation of Public subnets, one for each availability zone in the region._**
```sh
/*==== Public Subnets ======*/  
/* Creation of Public subnets, one for each availability zone in the region  */  
  
resource "aws_subnet" "public" {  
  count                   = local.subnets  
  vpc_id                  = aws_vpc.vpc.id  
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, count.index)  
  availability_zone       = data.aws_availability_zones.available_azs.names[count.index]  
  map_public_ip_on_launch = true  
  tags = {  
    Name = "${var.project}-${var.environment}-public${count.index + 1}"  
  }  
}
```
Count meta argument is used to create multiple subnet resources up to the number of availability zones.
```sh
#variables.tf  
locals {  
  subnets = length(data.aws_availability_zones.available_azs.names)  
}
```
**_Step 4: Creation of Private subnets, one for each availability zone in the region._**
```sh
/*==== Private Subnets ======*/  
/* Creation of Private  subnets, one for each availability zone in the region  */  
  
resource "aws_subnet" "private" {  
  count                   = local.subnets  
  vpc_id                  = aws_vpc.vpc.id  
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, (count.index + local.subnets))  
  availability_zone       = data.aws_availability_zones.available_azs.names[count.index]  
  map_public_ip_on_launch = true  
  tags = {  
    Name = "${var.project}-${var.environment}-private${count.index + 1}"  
  }  
}
```
**_Step 5: Creation of Elastic IP for NAT Gateway and Attachment of Elastic IP for the public access of NAT Gateway._**
```sh
/*==== Elastic IP ======*/  
/* Creation of Elastic IP for  NAT Gateway */  
  
resource "aws_eip" "nat_ip" {  
  vpc = true  
}  
  
/*==== Elastic IP Attachment ======*/  
/* Attachment of Elastic IP for the public access of NAT Gateway */  
  
resource "aws_nat_gateway" "nat_gw" {  
  allocation_id = aws_eip.nat_ip.id  
  subnet_id     = aws_subnet.public[1].id  
  
  tags = {  
    Name = "${var.project}-${var.environment}"  
  }  
  
  # To ensure proper ordering, it is recommended to add an explicit dependency  
  # on the Internet Gateway for the VPC.  
  depends_on = [aws_internet_gateway.igw]  
}
```
**_Step 6: Creation of route in the Public Route Table for public access via the Internet gateway for the vpc._**
```sh
/*==== Public Route Table ======*/  
/* Creation of route for public access via the Internet gateway for the vpc */  
  
resource "aws_route_table" "public" {  
  vpc_id = aws_vpc.vpc.id  
  
  route {  
    cidr_block = "0.0.0.0/0"  
    gateway_id = aws_internet_gateway.igw.id  
  }  
  
  tags = {  
    Name = "${var.project}-${var.environment}-public"  
  }  
}
```
**_Step 7 : Creation of Private Route Table with route for public access via the NAT gateway._**
```sh
/*==== Private Route Table =======*/  
/*Creation of Private Route Table with route for public access via the NAT gateway */  
  
resource "aws_route_table" "private" {  
  vpc_id = aws_vpc.vpc.id  
  
  route {  
    cidr_block     = "0.0.0.0/0"  
    nat_gateway_id = aws_nat_gateway.nat_gw.id  
  }  
  
  tags = {  
    Name = "${var.project}-${var.environment}-private"  
  }  
}
```
**_Step 8 : Association of Public route table with public subnets and Private route table with private subnets._**
```sh
/*==== Association Public Route Table ======*/  
/*Association of Public route table with public subnets. */  
  
resource "aws_route_table_association" "public" {  
  count          = local.subnets  
  subnet_id      = aws_subnet.public[count.index].id  
  route_table_id = aws_route_table.public.id  
}  
  
/*==== Association Private Route Table ======*/  
/*Association of Private route table with private subnets. */  
  
resource "aws_route_table_association" "private" {  
  count          = local.subnets  
  subnet_id      = aws_subnet.private[count.index].id  
  route_table_id = aws_route_table.private.id  
}
```
**_Step 9 : Creation of security group for Bastion Server._**
```sh
/*==== Security Group ======*/  
/*Creation of security group for Bastion Server */  
  
resource "aws_security_group" "bastion_sg" {  
  name_prefix = "${var.project}-${var.environment}-"  
  description = "Allow ssh from anywhere"  
  vpc_id      = aws_vpc.vpc.id  
  
  ingress {  
    from_port        = 22  
    to_port          = 22  
    protocol         = "tcp"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  egress {  
    from_port        = 0  
    to_port          = 0  
    protocol         = "-1"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  tags = {  
    Name = "${var.project}-${var.environment}-bastion-sg"  
  
  }  
  
  lifecycle {  
    create_before_destroy = true  
  }  
}
```
It is better to provide configure the lifecycle of the security group as create_before_destroy = true.

**_Step 10 : Creation of security group for front-end Server with ssh access from bastion security group._**
```sh
  
/*==== Security Group ======*/  
/*Creation of security group for frontend Server with ssh access from bastion security group*/  
  
resource "aws_security_group" "frontend_sg" {  
  name_prefix = "${var.project}-${var.environment}-"  
  description = "Allow http from anywhere and ssh from bastion-sg"  
  vpc_id      = aws_vpc.vpc.id  
  
  
  ingress {  
    from_port        = 80  
    to_port          = 80  
    protocol         = "tcp"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  ingress {  
    from_port        = 443  
    to_port          = 443  
    protocol         = "tcp"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  ingress {  
    from_port       = 22  
    to_port         = 22  
    protocol        = "tcp"  
    security_groups = [aws_security_group.bastion_sg.id]  
  }  
  
  
  egress {  
    from_port        = 0  
    to_port          = 0  
    protocol         = "-1"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  tags = {  
    Name = "${var.project}-${var.environment}-frontend-sg"  
  
  }  
  lifecycle {  
    create_before_destroy = true  
  }  
}
```
**_Step 11 : Creation of security group for front-end Server._**
```sh
/*==== Security Group ======*/  
/*Creation of security group for frontend Server */  
resource "aws_security_group" "backend_sg" {  
  name_prefix = "${var.project}-${var.environment}-"  
  description = "Allow sql from frontend-sg and ssh from bastion-sg"  
  vpc_id      = aws_vpc.vpc.id  
  
  
  ingress {  
    from_port       = 3306  
    to_port         = 3306  
    protocol        = "tcp"  
    security_groups = [aws_security_group.frontend_sg.id]  
  }  
  
  
  ingress {  
    from_port       = 22  
    to_port         = 22  
    protocol        = "tcp"  
    security_groups = [aws_security_group.bastion_sg.id]  
  }  
  
  
  egress {  
    from_port        = 0  
    to_port          = 0  
    protocol         = "-1"  
    cidr_blocks      = ["0.0.0.0/0"]  
    ipv6_cidr_blocks = ["::/0"]  
  }  
  
  tags = {  
    Name = "${var.project}-${var.environment}-backend-sg"  
  
  }  
  lifecycle {  
    create_before_destroy = true  
  }  
}
```
As we have created till security groups, Now it is time to create a public-private key pair for securely accessing the EC2 instances..

**_Step 12: Creation of key pair for server access._**
```sh
/*==== Keypair ======*/  
/*Creation of key pair for server access */  
  
resource "aws_key_pair" "ssh_key" {  
  
  key_name   = "${var.project}-${var.environment}"  
  public_key = file("mykey.pub")  
  tags = {  
    Name = "${var.project}-${var.environment}"  
  }  
}
```
**_Step 13 : Creation of EC2 instance for bastion server, front-end server and back-end server ._**
```sh
/*==== EC2 Instance Launch ======*/  
/*Creation of EC2 instance for bastion server */  
resource "aws_instance" "bastion" {  
  
  ami                         = var.instance_ami  
  instance_type               = var.instance_type  
  key_name                    = aws_key_pair.ssh_key.key_name  
  associate_public_ip_address = true  
  subnet_id                   = aws_subnet.public.1.id  
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]  
  user_data                   = file("setup_bastion.sh")  
  user_data_replace_on_change = true  
  
  tags = {  
    Name = "${var.project}-${var.environment}-bastion"  
  }  
}  
  
/*==== EC2 Instance Launch ======*/  
/*Creation of EC2 instance for frontend server */  
resource "aws_instance" "frontend" {  
  
  ami                         = var.instance_ami  
  instance_type               = var.instance_type  
  key_name                    = aws_key_pair.ssh_key.key_name  
  associate_public_ip_address = true  
  subnet_id                   = aws_subnet.public.0.id  
  vpc_security_group_ids      = [aws_security_group.frontend_sg.id]  
  user_data                   = file("setup_frontend.sh")  
  user_data_replace_on_change = true  
  
  tags = {  
    Name = "${var.project}-${var.environment}-frontend"  
  }  
}  
  
/*==== EC2 Instance Launch ======*/  
/*Creation of EC2 instance for backend server */  
resource "aws_instance" "backend" {  
  
  ami                         = var.instance_ami  
  instance_type               = var.instance_type  
  key_name                    = aws_key_pair.ssh_key.key_name  
  associate_public_ip_address = false  
  subnet_id                   = aws_subnet.private.0.id  
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]  
  user_data                   = file("setup_backend.sh")  
  user_data_replace_on_change = true  
  
  # To ensure proper ordering, it is recommended to add an explicit dependency  
  depends_on = [aws_nat_gateway.nat_gw]  
  
  tags = {  
    Name = "${var.project}-${var.environment}-backend"  
  }  
}
```
**_Step 14: Creation of private zone for private domain._**
```sh
/*==== Private Zone  ======*/  
/*Creation of private zone for private domain */  
resource "aws_route53_zone" "private" {  
  name = var.private_domain  
  
  vpc {  
    vpc_id = aws_vpc.vpc.id  
  }  
}
```
**_Step 15: Creation of A record to back-end private IP._**
```sh
/*==== Private Zone : A record  ======*/  
/*Creation of A record to backend private IP. */  
resource "aws_route53_record" "db" {  
  zone_id = aws_route53_zone.private.zone_id  
  name    = "db.${var.private_domain}"  
  type    = "A"  
  ttl     = 300  
  records = [aws_instance.backend.private_ip]  
}

**_Step16 : Creation of A record to front-end public IP._**

/*==== Public Zone : A record  ======*/  
/*Creation of A record to frontend public IP. */  
  
resource "aws_route53_record" "wordpress" {  
  zone_id = data.aws_route53_zone.selected.id  
  name    = "wordpress.${var.public_domain}"  
  type    = "A"  
  ttl     = 300  
  records = [aws_instance.frontend.public_ip]  
}
```
# **Configuration of servers during EC2 instance creation.**
```sh
resource "aws_instance" "frontend" {  
  .  
  .  
  .  
  user_data                   = file("setup_frontend.sh")  
  user_data_replace_on_change = true  
  }
```
When you examine the main.tf file, you will notice a section of the aws instance resource where a user data file is fed to AWS during the EC2 instance launch.

> setup_frontend.sh

This shell script is used to install apache, php and wordpress.
```sh
#!/bin/bash  
   
 echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config  
 echo "LANG=en_US.utf-8" >> /etc/environment  
 echo "LC_ALL=en_US.utf-8" >> /etc/environment  
 service sshd restart  
 hostnamectl set-hostname frontend  
 amazon-linux-extras install php7.4   
 yum install httpd -y  
 systemctl restart httpd  
 systemctl enable httpd  
 wget https://wordpress.org/latest.zip  
 unzip latest.zip  
 cp -rf wordpress/* /var/www/html/  
 mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php  
 chown -R apache:apache /var/www/html/*  
 cd  /var/www/html/  
 sed -i 's/database_name_here/blog/g' wp-config.php  
    sed -i 's/username_here/bloguser/g' wp-config.php  
 sed -i 's/password_here/bloguser123/g' wp-config.php  
 sed -i 's/localhost/db.pratheeshsatheeshkumar.local/g' wp-config.php
```
It also configure the wp-config.php file of the wordpress installation with database authentication values from back-end server.

> setup_backend.sh
```sh
 #!/bin/bash  
   
 echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config  
 echo "LANG=en_US.utf-8" >> /etc/environment  
 echo "LC_ALL=en_US.utf-8" >> /etc/environment  
 service sshd restart  
 hostnamectl set-hostname backend  
 amazon-linux-extras install php7.4 -y  
 rm -rf /var/lib/mysql/*  
 yum remove mysql -y  
    yum install httpd mariadb-server -y  
 systemctl restart mariadb.service  
    systemctl enable mariadb.service  
    mysqladmin -u root password 'mysql123'  
 mysql -u root -pmysql123 -e "create database blog;"  
 mysql -u root -pmysql123 -e "create user 'bloguser'@'%' identified by 'bloguser123';"  
 mysql -u root -pmysql123 -e "grant all privileges on blog.* to 'bloguser'@'%'"  
 mysql -u root -pmysql123 -e "flush privileges"
```
In this bash script back-end server is installed with mariadb-server and created and configured a database named “blog”.

# The concept of workspace that is implemented in this project.

You may have come across this block of code if you have already gone through the **variables.tf** file.
```sh
variable "instance_type" {}  
variable "instance_ami" {}  
variable "cidr_vpc" {}  
variable "environment" {}
```
These variables are not assigned with any values. Idea here is to feed these variables values while running **terraform apply**.

# Terraform Workspces.

Workspace is Terraform’s solution to manage multiple environments in a single folder using single code. Here we have a single code, but three set of environment variables in prod.tfvars, env.tfvars and test.tfvars

![](https://miro.medium.com/max/1400/1*ub4KgW-oYks925LNv1jZeQ.png)

> **prod.tfvars**
```sh
#prod.tfvars  
cidr_vpc      = "172.16.0.0/16"  
instance_type = "t2.micro"  
environment   = "prod"  
instance_ami  = "ami-0cca134ec43cf708f"
```
> **dev.tfvars**
```sh
cidr_vpc      = "172.17.0.0/16"  
instance_type = "t2.micro"  
environment   = "dev"  
instance_ami  = "ami-0cca134ec43cf708f"
```
> **test.tfvars**
```sh
cidr_vpc      = "172.18.0.0/16"  
instance_type = "t2.micro"  
environment   = "test"  
instance_ami  = "ami-0cca134ec43cf708f"
```
# How to create and manage workspaces.

The following code explains how I have created 3 different workspaces, which are prod, dev and test.
```sh
$ terraform workspace list  
* default  
  
(default)$ terraform workspace new prod  
  
Created and switched to workspace "prod"!  
  
You're now on a new, empty workspace. Workspaces isolate their state,  
so if you run "terraform plan" Terraform will not see any existing state  
for this configuration.  
  
(prod)$ terraform workspace new dev  
  
Created and switched to workspace "dev"!  
You're now on a new, empty workspace. Workspaces isolate their state,  
so if you run "terraform plan" Terraform will not see any existing state  
for this configuration.  
  
(env)$ terraform workspace new test  
  
Created and switched to workspace "test"!  
You're now on a new, empty workspace. Workspaces isolate their state,  
so if you run "terraform plan" Terraform will not see any existing state  
for this configuration.  
  
opc@instance-20221205-0008 ~/three-tier-with-tfvars (test)$ terraform workspace list  
  default  
  dev  
  prod  
* test
```
These workspaces contains their own terraform.tfstate file, which will be present once we do a terraform apply.

**Applying “prod workspace”**
```sh
(test)$ terraform workspace select prod  
  
Switched to workspace "prod".  
  
(prod)$ terraform apply -var-file prod.tfvars -auto-approve 
```

![](https://miro.medium.com/max/1400/1*rcaYKQ4Qk6DanMC0JfB7nw.png)

Infra created in AWS console will be as shown below. Its environment tag in prod.tfvars was environment = “prod”.

![](https://miro.medium.com/max/1400/1*Csywf8hZ_ZUINfrBRNpA0g.png)

Now, if I change my workspace to dev and apply with -var-file dev.tfvars
```sh

(prod)$ terraform workspace select dev  
  
Switched to workspace "dev".  
  
(dev)$ terraform apply -var-file dev.tfvars -auto-approve
```

We can see the new infra created with environment tag = “dev” is added with the existing “prod” infrastructure without interfering it.

![](https://miro.medium.com/max/1400/1*c79kkL1H6WMDKKCG39vmRQ.png)

Output of the project is a wordpress demo website in http://wordpress.example.com

![](https://miro.medium.com/max/1400/1*VpQYnlb-Pb10JDl_Ybc6Ew.png)


**Read my articles in medium.com.**
 <a target="_blank" href="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/3"><img src="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/3">

 <a target="_blank" href="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/2"><img src="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/2">

 <a target="_blank" href="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/1"><img src="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/1">

 <a target="_blank" href="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/0"><img src="https://github-readme-medium-recent-article.vercel.app/medium/@yespratheesh/0" >
