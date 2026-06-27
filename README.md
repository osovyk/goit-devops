# Lesson 7 — Kubernetes on AWS (EKS + Helm)

Terraform project for provisioning AWS infrastructure with an EKS Kubernetes cluster,
plus a Helm chart for deploying the Django application to the cluster.

Extends the Lesson 5 infrastructure (S3 backend, VPC, ECR) with an EKS module.

## Project Structure

```
.
├── main.tf              # Root module — provider config and module calls
├── backend.tf           # S3 remote state backend configuration
├── variables.tf         # All root-level input variables with defaults
├── outputs.tf           # Aggregated outputs from all modules
├── .gitignore
├── modules/
│   ├── s3-backend/      # S3 bucket + DynamoDB for Terraform state
│   │   ├── s3.tf
│   │   ├── dynamodb.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/             # VPC with public/private subnets
│   │   ├── vpc.tf
│   │   ├── routes.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/             # ECR container image repository
│   │   ├── ecr.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── eks/             # EKS Kubernetes cluster + managed node group
│       ├── eks.tf       # IAM role for cluster + aws_eks_cluster
│       ├── node.tf      # IAM roles for nodes + aws_eks_node_group
│       ├── variables.tf
│       └── outputs.tf
└── charts/
    └── django-app/      # Helm chart for the Django application
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml  # Kubernetes Deployment
            ├── service.yaml     # LoadBalancer Service
            ├── configmap.yaml   # Environment variables (PostgreSQL config)
            └── hpa.yaml         # HorizontalPodAutoscaler (2–6 pods, CPU 70%)
```

## Modules

### s3-backend
Creates the remote backend for storing Terraform state.

- S3 bucket with versioning, AES256 encryption, public access block, `force_destroy = true`
- DynamoDB table with `PAY_PER_REQUEST` billing and server-side encryption for state locking

### vpc
Creates a full VPC network across 3 availability zones.

- VPC with DNS support and hostnames enabled
- 3 public subnets (`map_public_ip_on_launch = true`) and 3 private subnets
- Internet Gateway, NAT Gateway (with Elastic IP), route tables

### ecr
Creates an ECR repository for Django Docker images.

- AES256 encryption, image scanning on push, lifecycle policy (keep last 10 images)
- Repository policy granting push/pull access to the AWS account

### eks
Creates a managed Kubernetes cluster on AWS EKS.

- IAM role for the EKS control plane with `AmazonEKSClusterPolicy`
- `aws_eks_cluster` with private and public endpoint access
- IAM role for worker nodes with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- Managed node group (`ON_DEMAND`, configurable instance type and scaling)

## Helm Chart — django-app

Located in `charts/django-app/`. Deploys the Django app from ECR to EKS.

| Template | Description |
|---|---|
| `deployment.yaml` | Deployment pulling Django image from ECR, env from ConfigMap |
| `service.yaml` | LoadBalancer exposing port 80 → container port 8000 |
| `configmap.yaml` | PostgreSQL connection env vars |
| `hpa.yaml` | HPA: 2–6 replicas, scale at CPU > 70% |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) v2
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3
- AWS credentials configured: `aws configure`

## Variables

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
| `cluster_name` | Name of the EKS cluster | `lesson-7-eks` |
| `kubernetes_version` | Kubernetes version for EKS | `1.31` |
| `instance_type` | EC2 instance type for worker nodes | `t3.medium` |
| `desired_size` | Desired number of worker nodes | `2` |
| `max_size` | Maximum number of worker nodes | `3` |
| `min_size` | Minimum number of worker nodes | `1` |

## Usage

### Step 1 — Bootstrap Terraform (first run)

The S3 bucket must exist before Terraform can use it as a backend.

```bash
# Comment out backend.tf, then:
rm -rf .terraform
terraform init
terraform apply
```

### Step 2 — Migrate state to S3 backend

```bash
# Uncomment backend.tf, then:
terraform init -migrate-state
# enter: yes
```

### Regular Terraform commands

```bash
terraform plan
terraform apply
terraform destroy
```

### Step 3 — Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region eu-west-1 --name lesson-7-eks
kubectl get nodes
```

### Step 4 — Build and push Django image to ECR

```bash
# Get ECR login token
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw ecr_repository_url | cut -d/ -f1)

# Build and push
docker build -t django-app .
docker tag django-app:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest
```

### Step 5 — Deploy with Helm

```bash
# Update image repository in values.yaml with your ECR URL first, then:
helm install django-app ./charts/django-app

# Check status
helm list
kubectl get pods
kubectl get svc

# Get the external LoadBalancer URL
kubectl get svc django-app-django -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Helm upgrade / uninstall

```bash
helm upgrade django-app ./charts/django-app
helm uninstall django-app
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
| `eks_cluster_name` | Name of the EKS cluster |
| `eks_cluster_endpoint` | API endpoint of the EKS cluster |
| `eks_node_role_arn` | IAM role ARN for EKS worker nodes |

## Important Notes

> **Cost warning:** EKS cluster ($0.10/hr), NAT Gateway, EC2 worker nodes, and Elastic IP
> all incur AWS charges. Always run `terraform destroy` after testing.

> **EKS takes ~15 minutes** to provision — this is normal for the control plane.

> **Destroy order:** Running `terraform destroy` removes the S3 bucket used as the backend.
> Before re-applying, comment out `backend.tf` and run:
> ```bash
> rm -rf .terraform
> terraform init
> ```

> **values.yaml image URL:** Replace `<ACCOUNT_ID>` in `charts/django-app/values.yaml`
> with your AWS account ID, or set it via: `helm install django-app ./charts/django-app --set image.repository=<ECR_URL>`
