#uses env var TF_VAR_DD_API_KEY
variable "DD_API_KEY" {
    type = string
    description = "Datadog API key"
}

#uses env var TF_VAR_DD_APP_KEY
variable "DD_APP_KEY" {
  type = string
  description = "Datadog APP key"
}

variable "aws_region" {
  default = "us-west-2"
}

variable "aws_profile" {
  default = "default"
}
