variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "name" {
  description = "Short name suffix for the instance (e.g. 'bastion', 'app', 'jenkins')"
  type        = string
  default     = "server"
}

variable "ami_id" {
  description = "AMI ID for the instance (use ap-south-1 AMI for Mumbai)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "Name of IAM instance profile to attach"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script (base64 or raw)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "create_eip" {
  description = "Whether to create and attach an Elastic IP"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
