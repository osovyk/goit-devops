variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "rosovyk-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones for subnets"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "vpc"
}

variable "ecr_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "lesson-5-ecr"
}

variable "scan_on_push" {
  description = "Enable image scanning on push for ECR"
  type        = bool
  default     = true
}
