# Terraform Modules

Reusable Terraform modules for AWS infrastructure.

## Modules

| Module | Description | Used In |
|--------|-------------|---------|
| [vpc](./vpc) | VPC + Public/Private Subnets + IGW + NAT | Every project |
| [security-group](./security-group) | Flexible SG with ingress/egress rules | Every project |
| [ec2](./ec2) | EC2 instance with optional EIP + user data | Common |
| [eks](./eks) | EKS Cluster + Node Group | DevHub-style projects |
| [rds](./rds) | RDS (MySQL/Postgres) with subnet group | Database projects |

## Usage Example

```hcl
module "vpc" {
  source = "git::https://github.com/<your-org>/terraform-modules.git//vpc?ref=v1.0.0"

  project_name       = "devhub"
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones = ["ap-south-1a", "ap-south-1b"]
  enable_nat_gateway = true
}

module "security_group" {
  source = "git::https://github.com/<your-org>/terraform-modules.git//security-group?ref=v1.0.0"

  project_name = "devhub"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id

  ingress_rules = [
    { from_port = 80,  to_port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

module "ec2" {
  source = "git::https://github.com/<your-org>/terraform-modules.git//ec2?ref=v1.0.0"

  project_name      = "devhub"
  environment       = "prod"
  ami_id            = "ami-0f58b397bc5c1f2e8"
  instance_type     = "t3.medium"
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security_group.security_group_id]
  key_name          = "my-key"
}

module "rds" {
  source = "git::https://github.com/<your-org>/terraform-modules.git//rds?ref=v1.0.0"

  project_name       = "devhub"
  environment        = "prod"
  engine             = "postgres"
  engine_version     = "15.3"
  instance_class     = "db.t3.micro"
  db_name            = "devhub"
  username           = "admin"
  password           = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_group.security_group_id]
}

module "eks" {
  source = "git::https://github.com/<your-org>/terraform-modules.git//eks?ref=v1.0.0"

  project_name       = "devhub"
  environment        = "prod"
  cluster_version    = "1.29"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_group.security_group_id]

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 4
    }
  }
}
```

## Versioning

Tag your releases so consumers can pin a version:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Requirements

- Terraform >= 1.3
- AWS Provider >= 5.0
