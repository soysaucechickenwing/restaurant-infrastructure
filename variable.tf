variable "aws_region" {
	default = "us-east-1"
}

variable "app_name" {
	default = "restaurant"
}

variable "db_password" {
	sensitive = true
}

variable "stripe_webhook_secret" {
	sensitive = true
}

variable "stripe_secret_key" {
	sensitive = true
}

variable "domain_name" {
  
}
