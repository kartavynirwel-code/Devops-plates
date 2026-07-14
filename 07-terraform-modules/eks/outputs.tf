output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = aws_eks_cluster.this.version
}

output "node_role_arn" {
  description = "ARN of the IAM role used by node groups"
  value       = aws_iam_role.node.arn
}

output "node_group_ids" {
  description = "IDs of the created node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.id }
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region <your-region>"
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (used in IRSA role trust policies)"
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  description = "Issuer URL of the EKS OIDC provider (without https://, for trust policy StringEquals key)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}
