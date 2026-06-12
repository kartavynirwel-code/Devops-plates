variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "engine" {
  description = "Database engine (mysql or postgres)"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["mysql", "postgres"], var.engine)
    error_message = "engine must be 'mysql' or 'postgres'."
  }
}

variable "engine_version" {
  description = "Engine version (e.g. '15.3' for postgres, '8.0' for mysql)"
  type        = string
  default     = "15.3"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "parameter_group_family" {
  description = "DB parameter group family (e.g. postgres15, mysql8.0)"
  type        = string
  default     = "postgres15"
}

variable "db_parameters" {
  description = "List of DB parameters to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "password" {
  description = "Master password — use a secrets manager in production"
  type        = string
  sensitive   = true
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max storage for autoscaling in GB (0 to disable)"
  type        = number
  default     = 100
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (use private subnets)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set false for prod)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
