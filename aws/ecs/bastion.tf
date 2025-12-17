# Bastion Host for accessing private resources (DocumentDB, Redis)

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  # SSH access - restrict to your IP for better security
  ingress {
    description = "SSH from anywhere (restrict in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Service = "bastion"
  }
}

# Allow bastion to connect to DocumentDB
resource "aws_vpc_security_group_ingress_rule" "docdb_from_bastion" {
  count                        = var.enable_managed_database ? 1 : 0
  security_group_id            = aws_security_group.docdb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.bastion.id

  tags = {
    Service = "bastion"
  }
}

# Allow bastion to connect to Redis
resource "aws_vpc_security_group_ingress_rule" "redis_from_bastion" {
  security_group_id            = aws_security_group.redis.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.bastion.id

  tags = {
    Service = "bastion"
  }
}

# IAM role for SSM Session Manager (no SSH keys needed)
resource "aws_iam_role" "bastion" {
  name = "${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Service = "bastion"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Service = "bastion"
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    # Install mongosh
    cat <<EOL > /etc/yum.repos.d/mongodb-org-7.0.repo
    [mongodb-org-7.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://pgp.mongodb.com/server-7.0.asc
    EOL
    dnf install -y mongodb-mongosh

    # Download DocumentDB CA certificate
    cd /home/ec2-user
    wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
    chown ec2-user:ec2-user global-bundle.pem

    # Install redis-cli
    dnf install -y redis6
  EOF

  tags = {
    Name    = "${var.environment}-bastion"
    Service = "bastion"
  }
}
