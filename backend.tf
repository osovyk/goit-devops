terraform {
  backend "s3" {
    bucket         = "rosovyk-terraform-state"
    key            = "lesson-9/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
