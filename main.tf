data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

data "local_file" "ssh_key" {
  filename = pathexpand("~/.ssh/mcp-ec2.pub")
}

resource "aws_key_pair" "default" {
  key_name   = "reka-terraform"
  public_key = data.local_file.ssh_key.content
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "default" {
  name        = "allow_ssh_reka"
  description = "Allow SSH inbound traffic from my IP"
  vpc_id      = aws_vpc.default.id

  ingress {
    description = "Open all incoming ports"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table" "default" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

resource "aws_route_table_association" "default" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.default.id
}

resource "aws_instance" "default" {
  ami                    = "ami-015f3aa67b494b27e"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.default.key_name
  subnet_id              = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.default.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "reka-terraform"
  }
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.default.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ec2-user@${aws_instance.default.public_ip}"
}
