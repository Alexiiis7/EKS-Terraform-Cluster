variable "AWS_ACCESS_KEY" {
    description = "aws access key"
    type        = string
    default     = "(insert aws access key here)"
}

variable "AWS_SECRET_KEY" {
    description = "aws secret key"
    type        = string
    default     = "(insert aws secret key here)"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-south-2"
}
