output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "route53_nameservers" {
  description = "Route53 nameservers - add these to Namecheap"
  value       = aws_route53_zone.main.name_servers
}