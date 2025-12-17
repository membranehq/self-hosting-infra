############################################
# MongoDB on EC2
############################################

variable "enable_mongodb_ec2" {
  type        = bool
  default     = false
  description = "Enable MongoDB on EC2 instance (alternative to DocumentDB)"
}

variable "mongodb_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for MongoDB"
}

variable "mongodb_volume_size" {
  type        = number
  default     = 50
  description = "EBS volume size in GB for MongoDB data"
}

variable "mongodb_admin_username" {
  type        = string
  default     = "mongoadmin"
  description = "MongoDB admin username"
}

variable "mongodb_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "MongoDB admin password"
}

############################################
# Security Group
############################################
resource "aws_security_group" "mongodb" {
  count       = var.enable_mongodb_ec2 ? 1 : 0
  name        = "${var.environment}-mongodb-sg"
  description = "Security group for MongoDB EC2 instance"
  vpc_id      = aws_vpc.main.id

  # MongoDB port from ECS tasks
  ingress {
    description     = "MongoDB from ECS tasks"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # MongoDB port from bastion
  ingress {
    description     = "MongoDB from bastion"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.environment}-mongodb-sg"
    Service = "mongodb"
  }
}

############################################
# IAM Role for MongoDB EC2
############################################
resource "aws_iam_role" "mongodb" {
  count = var.enable_mongodb_ec2 ? 1 : 0
  name  = "${var.environment}-mongodb-role"

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
    Service = "mongodb"
  }
}

resource "aws_iam_role_policy_attachment" "mongodb_ssm" {
  count      = var.enable_mongodb_ec2 ? 1 : 0
  role       = aws_iam_role.mongodb[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 access for backups
resource "aws_iam_role_policy" "mongodb_backup" {
  count = var.enable_mongodb_ec2 ? 1 : 0
  name  = "${var.environment}-mongodb-backup"
  role  = aws_iam_role.mongodb[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.tmp.arn,
        "${aws_s3_bucket.tmp.arn}/mongodb-backups/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "mongodb" {
  count = var.enable_mongodb_ec2 ? 1 : 0
  name  = "${var.environment}-mongodb-profile"
  role  = aws_iam_role.mongodb[0].name

  tags = {
    Service = "mongodb"
  }
}

############################################
# EBS Volume for MongoDB Data
############################################
resource "aws_ebs_volume" "mongodb_data" {
  count             = var.enable_mongodb_ec2 ? 1 : 0
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.mongodb_volume_size
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true

  tags = {
    Name    = "${var.environment}-mongodb-data"
    Service = "mongodb"
  }
}

############################################
# MongoDB EC2 Instance
############################################
resource "aws_instance" "mongodb" {
  count                  = var.enable_mongodb_ec2 ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.mongodb_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.mongodb[0].id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb[0].name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install MongoDB 8.0
    cat <<EOL > /etc/yum.repos.d/mongodb-org-8.0.repo
    [mongodb-org-8.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/8.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://pgp.mongodb.com/server-8.0.asc
    EOL

    dnf install -y mongodb-org

    # Wait for EBS volume to be attached
    while [ ! -e /dev/nvme1n1 ]; do
      echo "Waiting for EBS volume..."
      sleep 5
    done

    # Format and mount data volume (only if not already formatted)
    if ! blkid /dev/nvme1n1; then
      mkfs.xfs /dev/nvme1n1
    fi

    mkdir -p /data/db
    echo '/dev/nvme1n1 /data/db xfs defaults,nofail 0 2' >> /etc/fstab
    mount -a
    chown mongod:mongod /data/db

    # Configure MongoDB (journal is always enabled in MongoDB 8.0)
    cat <<EOL > /etc/mongod.conf
    storage:
      dbPath: /data/db

    systemLog:
      destination: file
      logAppend: true
      path: /var/log/mongodb/mongod.log

    net:
      port: 27017
      bindIp: 0.0.0.0

    security:
      authorization: enabled

    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
    EOL

    # Start MongoDB without auth first to create admin user
    cat <<EOL > /etc/mongod-init.conf
    storage:
      dbPath: /data/db

    systemLog:
      destination: file
      logAppend: true
      path: /var/log/mongodb/mongod.log

    net:
      port: 27017
      bindIp: 127.0.0.1

    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
    EOL

    # Start MongoDB temporarily without auth
    mongod --config /etc/mongod-init.conf --fork

    # Wait for MongoDB to start
    sleep 10

    # Create admin user
    mongosh --eval '
      db = db.getSiblingDB("admin");
      if (db.getUsers().users.length === 0) {
        db.createUser({
          user: "${var.mongodb_admin_username}",
          pwd: "${var.mongodb_admin_password}",
          roles: [
            { role: "userAdminAnyDatabase", db: "admin" },
            { role: "readWriteAnyDatabase", db: "admin" },
            { role: "dbAdminAnyDatabase", db: "admin" },
            { role: "clusterAdmin", db: "admin" }
          ]
        });
        print("Admin user created");
      } else {
        print("Admin user already exists");
      }
    '

    # Create application database and user
    mongosh --eval '
      db = db.getSiblingDB("engine");
      if (db.getUsers().users.length === 0) {
        db.createUser({
          user: "${var.mongodb_admin_username}",
          pwd: "${var.mongodb_admin_password}",
          roles: [
            { role: "readWrite", db: "engine" },
            { role: "dbAdmin", db: "engine" }
          ]
        });
        print("Engine user created");
      }
    '

    # Stop temporary MongoDB
    mongod --shutdown --dbpath /data/db

    # Start MongoDB with auth enabled
    systemctl enable mongod
    systemctl start mongod

    # Setup daily backup cron job
    cat <<'BACKUP' > /usr/local/bin/mongodb-backup.sh
    #!/bin/bash
    BACKUP_DIR="/tmp/mongodb-backup-$(date +%Y%m%d-%H%M%S)"
    mongodump --uri="mongodb://${var.mongodb_admin_username}:${var.mongodb_admin_password}@localhost:27017/engine?authSource=admin" --out="$BACKUP_DIR"
    tar -czf "$BACKUP_DIR.tar.gz" -C /tmp "$(basename $BACKUP_DIR)"
    aws s3 cp "$BACKUP_DIR.tar.gz" "s3://${aws_s3_bucket.tmp.id}/mongodb-backups/"
    rm -rf "$BACKUP_DIR" "$BACKUP_DIR.tar.gz"
    # Keep only last 7 days of backups
    aws s3 ls "s3://${aws_s3_bucket.tmp.id}/mongodb-backups/" | while read -r line; do
      file_date=$(echo $line | awk '{print $1}')
      file_name=$(echo $line | awk '{print $4}')
      if [[ $(date -d "$file_date" +%s) -lt $(date -d "7 days ago" +%s) ]]; then
        aws s3 rm "s3://${aws_s3_bucket.tmp.id}/mongodb-backups/$file_name"
      fi
    done
    BACKUP

    chmod +x /usr/local/bin/mongodb-backup.sh
    echo "0 3 * * * root /usr/local/bin/mongodb-backup.sh" > /etc/cron.d/mongodb-backup

    echo "MongoDB setup complete!"
  EOF

  tags = {
    Name    = "${var.environment}-mongodb"
    Service = "mongodb"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

############################################
# Attach EBS Volume
############################################
resource "aws_volume_attachment" "mongodb_data" {
  count       = var.enable_mongodb_ec2 ? 1 : 0
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mongodb_data[0].id
  instance_id = aws_instance.mongodb[0].id
}

############################################
# Private DNS Record
############################################
resource "aws_service_discovery_service" "mongodb" {
  count = var.enable_mongodb_ec2 ? 1 : 0
  name  = "mongodb"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  lifecycle {
    ignore_changes = [health_check_custom_config]
  }
}

resource "aws_service_discovery_instance" "mongodb" {
  count       = var.enable_mongodb_ec2 ? 1 : 0
  instance_id = "mongodb-ec2"
  service_id  = aws_service_discovery_service.mongodb[0].id

  attributes = {
    AWS_INSTANCE_IPV4 = aws_instance.mongodb[0].private_ip
  }
}

############################################
# Outputs
############################################
output "mongodb_ec2_private_ip" {
  value       = var.enable_mongodb_ec2 ? aws_instance.mongodb[0].private_ip : null
  description = "MongoDB EC2 instance private IP"
}

output "mongodb_ec2_instance_id" {
  value       = var.enable_mongodb_ec2 ? aws_instance.mongodb[0].id : null
  description = "MongoDB EC2 instance ID"
}

output "mongodb_ec2_dns" {
  value       = var.enable_mongodb_ec2 ? "mongodb.${aws_service_discovery_private_dns_namespace.main.name}" : null
  description = "MongoDB private DNS name"
}
