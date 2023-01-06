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

/*==== IGW ======*/
/* Create internet gateway for the public subnets and attach with vpc */

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
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
/*==== Keypair ======*/
/*Creation of key pair for server access */

resource "aws_key_pair" "ssh_key" {

  key_name   = "${var.project}-${var.environment}"
  public_key = file("mykey.pub")
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}


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
/*==== Private Zone  ======*/
/*Creation of private zone for private domain */
resource "aws_route53_zone" "private" {
  name = var.private_domain

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}

/*==== Private Zone : A record  ======*/
/*Creation of A record to backend private IP. */
resource "aws_route53_record" "db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.private_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.backend.private_ip]
}

/*==== Public Zone : A record  ======*/
/*Creation of A record to frontend public IP. */

resource "aws_route53_record" "wordpress" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "wordpress.${var.public_domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.frontend.public_ip]
}


