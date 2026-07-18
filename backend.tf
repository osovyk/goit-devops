terraform {
  backend "s3" {
    bucket         = "rosovyk-terraform-state"
    key            = "final-project/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
