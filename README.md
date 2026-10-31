# aws-platform

Terraform for everything the MERN platform runs on **Amazon Web Services** — a **standby** cloud. Its EKS cluster is fully configured but its node group normally has **0 nodes**; it is scaled up automatically when the primary cloud (GCP) fails.

**Region:** `ap-south-1` (2 availability zones) · **Terraform** 1.16 · **Remote state:** S3 `ppmcad16a-tfstate-<account>-ap-south-1` (encrypted, versioned, S3 lock file)

## Stacks

Each folder is its own Terraform stack with its own state. Apply them in this order.

| Stack | Creates | Lifetime |
|---|---|---|
| `bootstrap/` | state bucket, GitHub OIDC provider + plan/apply roles, monthly budget | once |
| `environments/prod/foundation/` | ECR repository per service (immutable tags), backup bucket, roles: `gha-push-<service>` (push to its own repo only), backup/restore federated from GKE, `gha-failover-wake` (describe + resize the node group only), Jenkins deployer federated from GKE | permanent |
| `environments/prod/cluster/` | VPC with public/private subnets in 2 AZs, NAT gateway + Elastic IP, EKS `prod-eks` (Pod Identity, API allow-list), managed node group `default` 2 × `t3.large` (min/desired managed outside Terraform so it can sleep at 0), Elastic IP for the entrance | per session |
| `environments/prod/addons/` | EBS CSI driver, AWS Load Balancer Controller, Envoy Gateway (NLB), External Secrets (+ SSM Parameter Store access), kube-prometheus-stack, Loki, Alloy, OpenCost, platform-config chart, access entry for Jenkins | per session |

Reusable modules: `modules/network`, `modules/eks`, `modules/ecr`.

## Dependencies

| Depends on | For |
|---|---|
| [gcp-platform](https://github.com/ppmcad16a-cloud-platform/gcp-platform) | `gke_egress_ip` → EKS API allow-list; GKE's OIDC issuer for the Jenkins and backup roles |
| [observability-platform](https://github.com/ppmcad16a-cloud-platform/observability-platform) | alert rules module (`?ref=v1.1.0`) |
| [global-platform](https://github.com/ppmcad16a-cloud-platform/global-platform) | app secrets in SSM Parameter Store under `/mern/` |

| Used by | For |
|---|---|
| [global-platform](https://github.com/ppmcad16a-cloud-platform/global-platform) | ingress/egress IPs → DNS, load-balancer pool, Atlas allow-list |
| [platform-automation](https://github.com/ppmcad16a-cloud-platform/platform-automation) | session start/end; node group 0 ↔ 2 for sleep/wake; `failover-wake.yml` |
| [platform-deployments](https://github.com/ppmcad16a-cloud-platform/platform-deployments) | Jenkins deploys into namespace `mern` |
| service repos | GitHub Actions push images to ECR |

## Usage

Normally driven by `platform-automation`. By hand:

```bash
aws sso login --profile HeroviredProfile && export AWS_PROFILE=HeroviredProfile
cd environments/prod/foundation && terraform init && terraform plan && terraform apply
echo "admin_cidr = \"$(curl -s https://api.ipify.org)/32\"" > ../cluster/terraform.tfvars
cp ../cluster/terraform.tfvars ../addons/terraform.tfvars
cd ../cluster && terraform init && terraform apply
aws eks update-kubeconfig --name prod-eks --region ap-south-1
cd ../addons && terraform init && terraform apply
```

Sleep / wake the standby: `aws eks update-nodegroup-config --cluster-name prod-eks --nodegroup-name default --scaling-config minSize=0,maxSize=3,desiredSize=0` (wake: `minSize=2,desiredSize=2`).

## Rules

* Plain `terraform init`, committed lock files, no secrets in git, `terraform.tfvars` holds only your IP.
* Destroy `addons` **before** `cluster`: the Load Balancer Controller must delete Envoy's NLB and the EBS CSI driver its volumes first. `down.yml` checks for leftover `k8s-*` load balancers and volumes and stops if any remain.
* Scaling the node group to 0 drains the nodes; PodDisruptionBudgets can hold the last pods for up to 30 min — drain with `kubectl drain -l eks.amazonaws.com/nodegroup=default --disable-eviction --force --ignore-daemonsets --delete-emptydir-data` to finish at once.
