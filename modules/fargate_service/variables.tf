# modules/fargate_service/variables.tf

variable "service_name" { type = string }
variable "cluster_id" { type = string }
variable "execution_role_arn" { type = string }
variable "container_image" { type = string }
variable "container_port" { type = number, default = 80 }
variable "cpu" { type = number, default = 256 }
variable "memory" { type = number, default = 512 }
variable "desired_count" { type = number, default = 1 }
variable "private_subnets" { type = list(string) }
variable "service_security_group_id" { type = string }