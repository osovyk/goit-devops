# Lesson 5 — Terraform AWS Infrastructure

Terraform project for provisioning AWS infrastructure using a modular approach.
Includes S3 remote state backend, VPC networking, and ECR container registry.

## Project Structure

```
.
├── main.tf              # Root module — provider config and module calls
├── backend.tf           # S3 remote state backend configuration
├── outputs.tf           # Aggregated outputs from all modules
├── .gitignore           # Ignored files (state, cache, secrets)
└── modules/
    ├── s3-backend/      # S3 bucket + DynamoDB for Terraform state
    │   ├── s3.tf        # S3 bucket with versioning and ownership controls
    │   ├── dynamodb.tf  # DynamoDB table for state locking
    │   ├── variables.tf
    │   └── outputs.tf
    ├── vpc/             # VPC with public/private subnets
    │   ├── vpc.tf       # VPC, subnets, Internet Gateway, NAT Gateway
    │   ├── routes.tf    # Route tables and associations
    │   ├── variables.tf
    │   └── outputs.tf
    └── ecr/             # ECR container image repository
        ├── ecr.tf       # Repository, lifecycle policy, access policy
        ├── variables.tf
        └── outputs.tf
```

## Modules

### s3-backend
Creates the remote backend for storing Terraform state.

- S3 bucket with versioning enabled and `BucketOwnerEnforced` ownership
- `force_destroy = true` to allow clean removal of versioned state files
- DynamoDB table with `PAY_PER_REQUEST` billing and `LockID` hash key for state locking

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

## Usage

### First run (bootstrap S3 backend)

The S3 bucket must exist before Terraform can use it as a backend.
On first run, comment out `backend.tf`, apply to create the bucket, then re-enable it:

```bash
# 1. Comment out backend.tf, then:
terraform init
terraform apply

# 2. Uncomment backend.tf, then migrate state to S3:
terraform init -reconfigure
```

### Regular commands

```bash
# Initialize Terraform and download providers
terraform init

# Preview infrastructure changes
terraform plan

# Apply changes to AWS
terraform apply

# Destroy all resources
terraform destroy
```

### Useful flags

```bash
terraform plan -out=tfplan        # Save plan to file
terraform apply tfplan            # Apply saved plan
terraform apply -auto-approve     # Skip confirmation prompt
terraform destroy -target=module.vpc  # Destroy a single module
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
> used as the backend. Before re-applying, comment out `backend.tf` and run
> `terraform init -reconfigure` to switch back to local state.
