variable "dd_api_key" {
  description = "Datadog API key — must have Remote Configuration enabled"
  type        = string
  sensitive   = true
}

variable "dd_app_key" {
  description = "Datadog Application key"
  type        = string
  sensitive   = true
}
