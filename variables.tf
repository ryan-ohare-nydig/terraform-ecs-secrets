variable "cpu" {
  default     = "1024"
  description = "Task CPU"
}

variable "memory" {
  default     = "512"
  description = "Task Memory"
}

variable "shared_credentials_file" {
  default = "~/.aws/credentials"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "aws_session_token" {}
