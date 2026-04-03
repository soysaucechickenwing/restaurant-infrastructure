resource "aws_ecr_repository" "backend" {
  name = "${var.app_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.app_name}-backend"
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
    repository = aws_ecr_repository.backend.name
    policy = jsonencode({
        rules = [{
            rulePriority = 1
            description = "Keep last 5 images"
            selection = {
                tagStatus = "any"
                countType = "imageCountMoreThan"
                countNumber = 5
            }
            action = {
                type = "expire"
            }
        }]
    })
    
}

resource "aws_db_subnet_group" "main" {
  name = "${var.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
    identifier = "${var.app_name}-mysql"
    engine = "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    allocated_storage = 20

    db_name = "restaurant"
    username = "admin"
    password = var.db_password

    db_subnet_group_name = aws_db_subnet_group.main.name
    vpc_security_group_ids = [aws_security_group.rds.id]

    skip_final_snapshot = true
    backup_retention_period = 7
    multi_az = false
    tags = {
        Name = "${var.app_name}-mysql"
    }
}