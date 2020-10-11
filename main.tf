provider "aws" {
  region     = "ap-south-1"
   profile = "gaurav"
}

################ Creating VPC ##############################

resource "aws_vpc" "gaurav-vpc" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = true
  instance_tenancy = "default"
  tags = {
    Name = "gaurav-vpc-task3"
  }
}

################ Creating VPC ##############################

################ Creating Public and Private Subnet ##############################

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.gaurav-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.gaurav-vpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private_subnet"
  }
}

################ Creating Public and Private Subnet ##############################

######### Creating Security Group for Public instance and Private instance########

resource "aws_security_group" "public_subnets_wordpress_SG" {
  name        = "public_gaurav_vpc"
  description = "ssh,http"
  vpc_id      = aws_vpc.gaurav-vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "public_subnets_wordpress_SG"
  }
}

resource "aws_security_group" "private_subnets_mysql_SG" {
  name        = "private_gaurav_vpc"
  description = "ssh,http for private access only "
  vpc_id      = aws_vpc.gaurav-vpc.id

 
   ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.public_subnets_wordpress_SG.id}" ]
  }
   ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.public_subnets_wordpress_SG.id}" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private_subnets_mysql_SG"
  }
  
}

######### Creating Security Group for Public instance and Private instance########

########### Creating an Internet Gateways ###########

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.gaurav-vpc.id

  tags = {
    Name = "gaurav-vpc-task3-gateways"
  }
}

########### Creating an Internet Gateways ###########

########### Creating Routing table and binding it with Public Subnet###########

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.gaurav-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

   tags = {
    Name = "public_subnets_routing_tables"
  }
  depends_on = [
    aws_internet_gateway.gateway
  ]
}



resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.r.id
  
  depends_on = [
    aws_subnet.public-subnet
       
  ]

}

resource "aws_eip" "byoip-ip" {
  vpc              = true
  public_ipv4_pool = "amazon"
}

resource "aws_nat_gateway" "gw" {
  depends_on = [aws_eip.byoip-ip]
  allocation_id = "${aws_eip.byoip-ip.id}"
  subnet_id     = "${aws_subnet.public-subnet.id}"
}


######## Creating subnet association ######
 
######### Launch EC2-instance  in public instance ######  

resource "aws_instance" "instance1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-subnet.id
  key_name = "deployer-key"
  associate_public_ip_address = true
  vpc_security_group_ids = [ "${aws_security_group.public_subnets_wordpress_SG.id}" ]
  tags = {
    Name = "WordPress"
  }
 
}
 
 ##### routing tables #######
resource "aws_route_table" "route_for_nat" {
  vpc_id = aws_vpc.gaurav-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.gw.id}"
  }

   tags = {
    Name = "private_subnet_routing_tables"
  }
  depends_on = [
    aws_nat_gateway.gw
  ]
} 

######## subnet association with private subnet ###
resource "aws_route_table_association" "routetable" {
  subnet_id      = "${aws_subnet.private-subnet.id}"
  route_table_id = "${aws_route_table.route_for_nat.id}"
  
  depends_on = [
    aws_subnet.private-subnet
       
  ]
}

######### Launch EC2-instance  in private instance ######  

resource "aws_instance" "instance2" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"  
  subnet_id = aws_subnet.private-subnet.id
  key_name = "deployer-key"
  associate_public_ip_address = false 
  vpc_security_group_ids = [ "${aws_security_group.private_subnets_mysql_SG.id}" ] 
     
  tags = {
    Name = "MySQL"
  }
 
}

output "public_ip" {
  value = aws_instance.instance1.public_ip
}
output "private_ip" {
  value = aws_instance.instance2.private_ip
}