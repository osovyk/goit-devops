# Lesson 9 — Jenkins + Terraform + ECR + Helm + Argo CD + RDS CI/CD

Terraform project for provisioning AWS infrastructure with an EKS Kubernetes cluster, a full
CI/CD pipeline (Jenkins building with Kaniko, pushing to ECR, updating the Helm chart), GitOps
delivery (Argo CD auto-syncing the chart into the cluster), and a database layer (a reusable
`rds` module that provisions either a standalone RDS instance or an Aurora cluster).

Extends the previous CI/CD infrastructure (S3 backend, VPC, ECR, EKS, Jenkins, Argo CD, Helm chart)
with the `rds` module — see [`modules/rds/README.md`](modules/rds/README.md) for full module
documentation (usage examples, all variables, how to switch RDS ⇄ Aurora / Postgres ⇄ MySQL).

## Pipeline flow

```text
push to app/ ──▶ Jenkins (Kubernetes agent + Kaniko)
                    1. builds app/Dockerfile
                    2. pushes image to ECR, tagged with the git short SHA
                    3. bumps charts/django-app/values.yaml `image.tag`
                    4. commits + pushes to $GIT_TARGET_BRANCH
                          │
                          ▼
                    Argo CD Application (watches charts/django-app on $GIT_TARGET_BRANCH)
                          │
                          ▼
                    auto-sync (prune + selfHeal) deploys the new tag to EKS
```

No static AWS credentials anywhere: the Jenkins agent's Kaniko container pushes to ECR using
IRSA (an IAM role assumed via the EKS cluster's OIDC provider), and the EBS CSI driver (needed
for Jenkins' PVC) uses IRSA too.

The chart-bump commit carries `[ci skip]` so an SCM-triggered pipeline doesn't re-trigger itself
on its own push. `options { disableConcurrentBuilds(); buildDiscarder(...) }` caps concurrent runs
and build history, and `post { always { cleanWs() } }` wipes the workspace after every run.

**This repo has no `main` branch** — it's lesson-per-branch (`lesson-3`, `lesson-4`, `lesson-5`,
`lesson-7`, ...). The branch Jenkins pushes to and Argo CD tracks is controlled by
`var.git_target_branch` (default `lesson-9`) and must be bumped each lesson.

## Versions

| Tool / Component | Version |
| --- | --- |
| Terraform | >= 1.15.7 |
| AWS Provider | ~> 6.52 |
| Helm | 4.2.2 |
| Kubernetes (EKS) | 1.36 |
| Jenkins chart (jenkins/jenkins) | 5.9.32 |
| Argo CD chart (argo/argo-cd) | 10.1.2 |
| AWS CLI | v2 |

## Project Structure

```text
.
├── main.tf              # Root module — aws/kubernetes/helm providers, module calls
├── backend.tf           # S3 remote state backend configuration (bucket + DynamoDB lock table)
├── variables.tf         # All root-level input variables with defaults
├── outputs.tf           # Aggregated outputs from all modules
├── Jenkinsfile           # CI pipeline: Kaniko build/push + Helm chart tag bump
├── .gitignore
├── app/                  # Django application source
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── manage.py
│   └── myproject/        # settings.py, urls.py, wsgi.py
├── modules/
│   ├── s3-backend/      # S3 bucket + DynamoDB for Terraform state
│   │   ├── s3.tf        # S3 bucket with versioning, encryption, public access block
│   │   ├── dynamodb.tf  # DynamoDB table with server-side encryption
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/             # VPC with public/private subnets
│   │   ├── vpc.tf       # VPC, subnets, Internet Gateway, NAT Gateway
│   │   ├── routes.tf    # Route tables and associations
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/             # ECR container image repository
│   │   ├── ecr.tf       # Repository with AES256 encryption, lifecycle policy, access policy
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/             # EKS Kubernetes cluster + managed node group
│   │   ├── eks.tf                # IAM role for cluster + aws_eks_cluster
│   │   ├── node.tf                # IAM roles for nodes + aws_eks_node_group
│   │   ├── irsa.tf                # IAM OIDC provider for the cluster (IRSA)
│   │   ├── aws_ebs_csi_driver.tf  # EBS CSI driver addon (IRSA) + default gp3 StorageClass
│   │   ├── providers.tf           # kubernetes provider (for the StorageClass)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds/              # Universal RDS/Aurora database module
│   │   ├── shared.tf      # DB subnet group, security group, locals, random password
│   │   ├── rds.tf          # Standalone aws_db_instance + parameter group (use_aurora = false)
│   │   ├── aurora.tf       # aws_rds_cluster + instances + parameter group (use_aurora = true)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md      # Usage examples, variables reference, RDS ⇄ Aurora / engine switching
│   ├── jenkins/          # Jenkins installed via Helm, Kubernetes agent + Kaniko
│   │   ├── jenkins.tf     # Namespace, GitHub credentials Secret, helm_release
│   │   ├── irsa.tf        # IAM role for the jenkins-agent service account (ECR push)
│   │   ├── providers.tf   # required_providers only — actual kubernetes/helm provider
│   │   │                  #   configs live in root main.tf so depends_on = [module.eks] works
│   │   ├── values.yaml    # Templated: JCasC global env vars, Kaniko pod template, resources
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── argo_cd/          # Argo CD installed via Helm
│       ├── argocd.tf      # helm_release "argocd" + helm_release "argocd_apps"
│       ├── providers.tf   # required_providers only — see note above
│       ├── values.yaml
│       ├── variables.tf
│       ├── outputs.tf
│       └── charts/        # Local chart rendering Argo CD Application/Repository resources
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               ├── application.yaml
│               └── repository.yaml
└── charts/
    └── django-app/      # Helm chart for the Django application
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml  # Kubernetes Deployment
            ├── service.yaml     # LoadBalancer Service (port 80 → 8000)
            ├── configmap.yaml   # PostgreSQL environment variables
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
- Internet Gateway, NAT Gateway (with Elastic IP), separate route tables

### ecr

Creates an ECR repository for Django Docker images.

- AES256 encryption, image scanning on push
- Lifecycle policy: keeps the last 10 images
- Repository policy granting push/pull access to the AWS account

### eks

Creates a managed Kubernetes cluster on AWS EKS.

- IAM role for the EKS control plane with `AmazonEKSClusterPolicy`
- `aws_eks_cluster` with private and public endpoint access, Kubernetes 1.36
- IAM role for worker nodes with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- Managed node group: `ON_DEMAND`, `t3.medium`, 2 desired / 1 min / 3 max
- IAM OIDC provider (`irsa.tf`) so pods can assume IAM roles via IRSA
- `aws-ebs-csi-driver` EKS addon (IRSA) + default `gp3` StorageClass — required for any pod
  requesting a PVC (e.g. Jenkins), since EKS ships no in-tree provisioner or default StorageClass

### jenkins

Installs Jenkins on the cluster via Helm, configured for CI builds with a Kubernetes agent.

- `helm_release` for `jenkins/jenkins`, namespace created by the module; called from root with
  `depends_on = [module.eks]` since the helm/kubernetes providers (configured once in root
  `main.tf`) need a live cluster before Terraform can even plan this module's resources
- `controller.resources` — requests `500m`/`512Mi`, limits `2000m`/`2048Mi`
- `serviceAccountAgent` "jenkins-agent" annotated with an IRSA role scoped to
  `ecr:GetAuthorizationToken` (account-wide, required by ECR) and push actions scoped to the
  single ECR repository ARN — no static AWS keys
- `agent.podTemplates.kaniko` — a Kubernetes agent pod template with a `gcr.io/kaniko-project/executor:debug`
  sidecar (`AWS_SDK_LOAD_CONFIG=true` so Kaniko authenticates to ECR via the pod's IRSA role)
- JCasC global env vars (`ECR_REPOSITORY_URL`, `AWS_REGION`, `GIT_REPO_URL`) injected into every
  pipeline so the `Jenkinsfile` never hardcodes an AWS account ID
- A Kubernetes Secret (`github-credentials`, labeled for the bundled Kubernetes Credentials
  Provider plugin) exposes the GitHub PAT supplied via `var.github_username` / `var.github_token`
  as Jenkins credentials id `github-credentials`, used by the `Jenkinsfile` to push tag bumps
- `additionalPlugins` includes `kubernetes-credentials-provider` (surfaces the Secret above as a
  Jenkins credential) and `ws-cleanup` (for the Jenkinsfile's `post { cleanWs() }`) — neither
  ships in the chart's default plugin set

### argo_cd

Installs Argo CD on the cluster via Helm, plus an `Application` that tracks `charts/django-app`.
Also called from root with `depends_on = [module.eks]`, same reasoning as `jenkins` above.

- `helm_release "argocd"` for `argo/argo-cd`, namespace created by the module
- `server.resources` and `repoServer.resources` — requests `100m`/`128Mi`, limits `500m`/`512Mi`
  on both, `replicas: 1` each
- `helm_release "argocd_apps"` installs a small local chart (`modules/argo_cd/charts`) that
  renders an Argo CD `Application` per entry in its `applications` list — currently one entry,
  `django-app`, pointed at `var.git_repo_url` / `charts/django-app` / `var.target_revision`
- `syncPolicy.automated { prune: true, selfHeal: true }` — Argo CD auto-applies every change
  pushed to `charts/django-app/values.yaml` (i.e. every Jenkins tag bump) with no manual sync
- The chart's `repository.yaml` template is included but unused for this public repo — it's there
  to document how to add Argo CD repository credentials if the repo is ever made private

### rds

Universal database module — see [`modules/rds/README.md`](modules/rds/README.md) for the full
writeup (usage examples, all variables/outputs, how to switch engines).

- `var.use_aurora` picks between a standalone `aws_db_instance` (`rds.tf`) or an
  `aws_rds_cluster` + `aws_rds_cluster_instance` set (`aurora.tf`) — mutually exclusive via
  `count = var.use_aurora ? 1 : 0` (and the inverse)
- Both paths share (`shared.tf`) a `aws_db_subnet_group`, a `aws_security_group` (ingress from
  `allowed_cidr_blocks` / `allowed_security_group_ids`), and a generated `random_password` used
  whenever `master_password` is left `null`
- Parameter group (`aws_db_parameter_group` or `aws_rds_cluster_parameter_group` to match) is
  seeded with baseline `max_connections` / `log_statement` / `work_mem` (Postgres) or
  `max_connections` / `general_log` / `sort_buffer_size` (MySQL), overridable via `db_parameters`
- `var.engine_family` (`"postgres"`/`"mysql"`) drives the actual `engine` string for both RDS
  (`postgres`/`mysql`) and Aurora (`aurora-postgresql`/`aurora-mysql`)
- Deployed in `module.vpc.private_subnets`, reachable from the VPC CIDR (`allowed_cidr_blocks`)

## Helm Chart — django-app

Located in `charts/django-app/`. Deploys the Django app from ECR to EKS.

| Template | Description |
| --- | --- |
| `deployment.yaml` | Deployment pulling Django image from ECR, env vars from ConfigMap |
| `service.yaml` | LoadBalancer — external port 80, container port 8000 |
| `configmap.yaml` | PostgreSQL connection env vars (POSTGRES_HOST, PORT, USER, DB, PASSWORD) |
| `hpa.yaml` | HPA: minReplicas 2 / maxReplicas 6 / CPU threshold 70% |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.15.7
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) v2
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 4.2.2
- AWS credentials configured: `aws configure`

## Variables

All defaults are defined in root `variables.tf`. Module variables intentionally have no defaults — root is the single source of truth.

| Variable | Description | Default |
| --- | --- | --- |
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
| `kubernetes_version` | Kubernetes version for EKS | `1.36` |
| `instance_type` | EC2 instance type for worker nodes. This AWS account is Free-Tier-restricted — must stay one of `t3.micro`/`t3.small`/`c7i-flex.large`/`m7i-flex.large` | `m7i-flex.large` |
| `desired_size` | Desired number of worker nodes | `2` |
| `max_size` | Maximum number of worker nodes | `3` |
| `min_size` | Minimum number of worker nodes | `1` |
| `jenkins_namespace` | Kubernetes namespace for Jenkins | `jenkins` |
| `jenkins_chart_version` | Version of the `jenkins/jenkins` chart | `5.9.32` |
| `argocd_namespace` | Kubernetes namespace for Argo CD | `argocd` |
| `argocd_chart_version` | Version of the `argo/argo-cd` chart | `10.1.2` |
| `git_repo_url` | HTTPS URL of this repo (Jenkins push target / Argo CD sync source) | `https://github.com/osovyk/goit-devops.git` |
| `git_target_branch` | Branch Jenkins pushes to / Argo CD tracks (no `main` here — bump each lesson) | `lesson-9` |
| `github_username` | GitHub username for Jenkins' push credentials | *(required, sensitive, no default)* |
| `github_token` | GitHub PAT (repo scope) for Jenkins' push credentials | *(required, sensitive, no default)* |
| `rds_identifier` | Base name for the RDS/Aurora resources | `lesson-9-db` |
| `rds_use_aurora` | `true` → Aurora cluster, `false` → standalone RDS instance | `false` |
| `rds_engine_family` | `"postgres"` or `"mysql"` | `postgres` |
| `rds_engine_version` | Engine version (must match `rds_engine_family`/`rds_use_aurora`) | `17.6` |
| `rds_parameter_group_family` | Parameter group family, e.g. `postgres17`, `aurora-postgresql17` | `postgres17` |
| `rds_instance_class` | Instance class for the RDS/Aurora instance(s). Free-Tier-restricted — `db.t3.micro` is the only confirmed-working class here | `db.t3.micro` |
| `rds_multi_az` | Multi-AZ for standalone RDS (ignored for Aurora) | `false` |
| `rds_aurora_instance_count` | Number of Aurora cluster instances | `1` |
| `rds_db_name` | Name of the default database | `myapp` |
| `rds_master_username` | Master username for the database. Avoid `"admin"` — reserved word for postgres on RDS | `dbadmin` |
| `rds_master_password` | Master password. Leave unset in `terraform.tfvars` to auto-generate | *(sensitive, `null` by default)* |
| `rds_backup_retention_period` | Days to retain automated backups. This Free-Tier account caps it below the module's own default (7) | `1` |

## Usage

### Step 1 — Bootstrap Terraform (first run only, on a fresh AWS account)

`backend.tf` is committed active (S3 + DynamoDB lock table), but that bucket/table must exist
*before* Terraform can use them as a backend. On a brand-new account, comment `backend.tf` out
first so the bootstrap run uses local state:

```bash
# Comment out backend.tf, then:
rm -rf .terraform
terraform init
terraform apply -target=module.s3_backend
```

### Step 2 — Migrate state to S3 backend

```bash
# Uncomment backend.tf again, then:
terraform init -migrate-state
# enter: yes
```

If the S3 bucket and DynamoDB table already exist (anyone re-cloning this repo), skip straight to
`terraform init` — `backend.tf` is already active, no bootstrap needed.

### Regular Terraform commands

Create a `terraform.tfvars` (already gitignored) with a GitHub [personal access token](https://github.com/settings/tokens)
that has push access to this repo — Jenkins needs it to commit tag bumps:

```hcl
github_username = "osovyk"
github_token     = "ghp_xxx..."
```

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

### Step 4 — Access Jenkins and create the pipeline job

```bash
# Admin password:
terraform output -raw jenkins_admin_password_command | bash

# UI address (LoadBalancer):
kubectl -n jenkins get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

In the Jenkins UI, create a **Pipeline** job (or Multibranch Pipeline) pointed at this repo's
`Jenkinsfile` on the `git_target_branch` branch (default `lesson-9`). Every build:
builds `app/Dockerfile` with Kaniko, pushes `<tag>` and `latest` to ECR, then bumps
`charts/django-app/values.yaml` and pushes back to that same branch.

### Step 5 — Access Argo CD

```bash
# Admin password:
terraform output -raw argocd_admin_password_command | bash

# UI address (LoadBalancer):
kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

The `django-app` Application is created automatically by `module.argo_cd` and auto-syncs on every
push to `charts/django-app` on the `git_target_branch` branch — no manual `helm install` needed
once Argo CD is up.

### Manual build/deploy (without Jenkins/Argo CD)

Still useful for local testing:

```bash
export ECR_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin $(echo $ECR_URL | cut -d/ -f1)

docker build -t django-app ./app
docker tag django-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

helm install django-app ./charts/django-app --set image.repository=$ECR_URL

kubectl get pods
kubectl get svc
kubectl get hpa
```

### Helm upgrade / uninstall

```bash
helm upgrade django-app ./charts/django-app
helm uninstall django-app
```

## Outputs

| Output | Description |
| --- | --- |
| `s3_bucket_name` | S3 bucket name for Terraform state |
| `dynamodb_table_name` | DynamoDB table name for state locking |
| `vpc_id` | VPC ID |
| `public_subnets` | List of public subnet IDs |
| `private_subnets` | List of private subnet IDs |
| `ecr_repository_url` | ECR repository URL for `docker push` |
| `eks_cluster_name` | Name of the EKS cluster |
| `eks_cluster_endpoint` | API endpoint of the EKS cluster |
| `eks_node_role_arn` | IAM role ARN for EKS worker nodes |
| `jenkins_namespace` | Kubernetes namespace Jenkins is installed into |
| `jenkins_admin_password_command` | Command to retrieve the Jenkins admin password |
| `argocd_namespace` | Kubernetes namespace Argo CD is installed into |
| `argocd_admin_password_command` | Command to retrieve the Argo CD initial admin password |
| `rds_endpoint` | RDS/Aurora connection endpoint |
| `rds_reader_endpoint` | Aurora reader endpoint (`null` for standalone RDS) |
| `rds_master_username` | RDS/Aurora master username |
| `rds_master_password` | RDS/Aurora master password (sensitive) |

## Important Notes

**Cost warning:** EKS cluster (~$0.10/hr), NAT Gateway, EC2 worker nodes, Elastic IP, two
LoadBalancers (Jenkins UI, Argo CD UI), and now an RDS instance/Aurora cluster all incur AWS
charges. Always run `terraform destroy` after testing. If Jenkins/Argo CD pods stay `Pending` due to
resource pressure on the two `t3.medium` nodes, bump `desired_size`/`instance_type`.

**EKS provisioning time:** ~15 minutes is normal for the control plane and node group.

**Destroy order:** `terraform destroy` also removes the S3 bucket used as the backend.
Before re-applying, comment out `backend.tf` and run:

```bash
rm -rf .terraform
terraform init
```

**GitHub credentials:** `github_username`/`github_token` have no default and must be supplied via
an untracked `terraform.tfvars` (see Step 2) — Jenkins needs push access to commit Helm chart tag
bumps back to the `git_target_branch` branch.

**`dynamodb_table` deprecation warning:** `terraform init` prints a warning that `dynamodb_table`
in `backend.tf` is deprecated in favor of `use_lockfile` (S3-native locking, Terraform 1.10+).
It's kept here deliberately — the `s3-backend` module already provisions the DynamoDB table for
locking, and this is the same field name used in the course material. Both work; only the warning
is cosmetic.
