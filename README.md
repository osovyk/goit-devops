# Lesson 5 — Terraform AWS Infrastructure

Terraform project for provisioning AWS infrastructure using a modular approach.
Includes S3 remote state backend, VPC networking, and ECR container registry.

## Project Structure

```
.
├── main.tf              # Root module — provider config and module calls
├── backend.tf           # S3 remote state backend configuration
├── variables.tf         # All root-level input variables with defaults
├── outputs.tf           # Aggregated outputs from all modules
├── .gitignore
└── modules/
    ├── s3-backend/      # S3 bucket + DynamoDB for Terraform state
    │   ├── s3.tf        # S3 bucket with versioning, encryption, public access block
    │   ├── dynamodb.tf  # DynamoDB table with server-side encryption
    │   ├── variables.tf
    │   └── outputs.tf
    ├── vpc/             # VPC with public/private subnets
    │   ├── vpc.tf       # VPC, subnets, Internet Gateway, NAT Gateway
    │   ├── routes.tf    # Route tables and associations
    │   ├── variables.tf
    │   └── outputs.tf
    └── ecr/             # ECR container image repository
        ├── ecr.tf       # Repository with AES256 encryption, lifecycle policy, access policy
        ├── variables.tf
        └── outputs.tf
```

## Modules

### s3-backend
Creates the remote backend for storing Terraform state.

- S3 bucket with versioning enabled
- AES256 server-side encryption
- Public access block (all public access disabled)
- `BucketOwnerEnforced` ownership controls
- `force_destroy = true` for clean removal of versioned state files
- DynamoDB table with `PAY_PER_REQUEST` billing and server-side encryption for state locking

### vpc
Creates a full VPC network across 3 availability zones.

- VPC with DNS support and DNS hostnames enabled
- 3 public subnets with `map_public_ip_on_launch = true`
- 3 private subnets
- Internet Gateway for public subnet outbound traffic
- NAT Gateway (with Elastic IP) for private subnet outbound traffic
- Separate route tables for public and private subnets

### ecr
Creates an ECR repository for Docker images.

- AES256 encryption at rest
- Image scanning on push enabled
- Lifecycle policy to retain the last 10 images
- Repository policy granting push/pull access to the AWS account root

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) v2
- AWS credentials configured:

```bash
aws configure
```

## Variables

All variables are defined in `variables.tf` with default values.
Override any variable at runtime with `-var="key=value"`.

| Variable | Description | Default |
|---|---|---|
| `aws_region` | AWS region to deploy resources | `eu-west-1` |
| `bucket_name` | S3 bucket name for Terraform state | `rosovyk-terraform-state` |
| `dynamodb_table_name` | DynamoDB table name for state locking | `terraform-locks` |
| `vpc_cidr_block` | CIDR block for the VPC | `10.0.0.0/16` |
| `public_subnets` | List of public subnet CIDRs | `["10.0.1.0/24", ...]` |
| `private_subnets` | List of private subnet CIDRs | `["10.0.4.0/24", ...]` |
| `availability_zones` | List of availability zones | `["eu-west-1a", ...]` |
| `vpc_name` | Name tag prefix for VPC resources | `vpc` |
| `ecr_name` | ECR repository name | `lesson-5-ecr` |
| `scan_on_push` | Enable ECR image scanning on push | `true` |

## Usage

### First run (bootstrap S3 backend)

The S3 bucket must exist before Terraform can use it as a backend.
On first run, comment out `backend.tf`, apply to create the bucket, then re-enable it:

```bash
# 1. Comment out backend.tf, then:
rm -rf .terraform
terraform init
terraform apply

# 2. Uncomment backend.tf, then migrate state to S3:
terraform init -migrate-state
# enter: yes
```

### Regular commands

```bash
# Initialize Terraform
terraform init

# Preview infrastructure changes
terraform plan

# Apply changes to AWS
terraform apply

# Destroy all resources
terraform destroy
```

### Override variables at runtime

```bash
terraform apply -var="aws_region=eu-central-1"
terraform apply -var="vpc_name=my-vpc" -var="ecr_name=my-app"
```

## Outputs

| Output | Description |
|---|---|
| `s3_bucket_name` | S3 bucket name for Terraform state |
| `dynamodb_table_name` | DynamoDB table name for state locking |
| `vpc_id` | VPC ID |
| `public_subnets` | List of public subnet IDs |
| `private_subnets` | List of private subnet IDs |
| `ecr_repository_url` | ECR repository URL for `docker push` |

## Important Notes

> **Cost warning:** NAT Gateway and Elastic IP incur AWS charges even when idle.
> Always run `terraform destroy` after testing to avoid unexpected bills.

> **Destroy order:** Running `terraform destroy` also removes the S3 bucket and DynamoDB table
> used as the backend. Before re-applying, comment out `backend.tf` and run:
> ```bash
> rm -rf .terraform
> terraform init
> ```
