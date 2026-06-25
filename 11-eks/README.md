# 11 - AWS EKS via Terraform

## Kya hai ye?
EKS = Elastic Kubernetes Service — AWS ka managed Kubernetes!

```
Self-managed K8s = Tu sab kuch manage karta hai
EKS              = AWS Control Plane manage karta hai,
                   tu sirf Worker Nodes manage karo!
```

**Real life analogy:**
EKS = Rented office (AWS building maintain karta hai)
Self-managed = Khud ka ghar (sab kuch khud karo)

## Architecture

```
          INTERNET
              │
         [IGW - Main Gate]
              │
     ┌────────VPC──────────┐
     │                     │
Public Subnet 1    Public Subnet 2
(AZ 1a)            (AZ 1b)
[NAT Gateway]
     │
Private Subnet 1   Private Subnet 2
(AZ 1a)            (AZ 1b)
[Worker Nodes]     [Worker Nodes]
     │                   │
     └──[EKS Cluster]────┘
        (Control Plane)
```

## Folder Structure

```
eks-terraform/
├── variables.tf   ← Variables define karo
├── main.tf        ← VPC + Networking
├── iam.tf         ← IAM Roles
├── eks.tf         ← EKS Cluster + Node Group
└── outputs.tf     ← Output values
```

## variables.tf

```hcl
variable "region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "my-eks-cluster"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  default = ["ap-south-1a", "ap-south-1b"]
}
```

## main.tf (VPC + Networking)

```hcl
provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.cluster_name}-vpc" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name                              = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.cluster_name}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.cluster_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.cluster_name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

## iam.tf

```hcl
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}
```

## eks.tf

```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids             = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_public_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
  tags       = { Name = var.cluster_name }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
  tags = { Name = "${var.cluster_name}-nodes" }
}
```

## outputs.tf

```hcl
output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "vpc_id" {
  value = aws_vpc.main.id
}
```

## Apply karo

```bash
terraform init
terraform plan
terraform apply
```

## kubectl Configure karo

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name my-eks-cluster

kubectl get nodes
```

## ⚠️ COST WARNING!

```
EKS Control Plane = $0.10/hour (~$72/month)
t3.medium x2      = ~$0.08/hour
NAT Gateway       = $0.045/hour
─────────────────────────────────
Total             = ~$6/day 💸

Kaam ho jaaye toh TURANT:
terraform destroy
```

## Interview Questions

**Q: EKS me Control Plane aur Worker Nodes ka difference?**
> Control Plane AWS manage karta hai — API server, etcd, scheduler.
> Worker Nodes hum manage karte hain — yahan actual pods chalte hain.

**Q: Worker Nodes private subnet me kyun rakhte hain?**
> Security ke liye — directly internet se accessible nahi hone chahiye.
> NAT Gateway se outbound internet access milta hai (image pull ke liye).

**Q: EKS me NAT Gateway kyun chahiye?**
> Private subnet ke worker nodes ko Docker images pull karni hoti hain.
> NAT Gateway outbound allow karta hai, inbound block karta hai.

**Q: count.index kya hota hai Terraform me?**
> count use karne pe loop chalta hai — count.index current iteration number.
> 0 se start hota hai, list se values pick karne ke liye use hota hai.
