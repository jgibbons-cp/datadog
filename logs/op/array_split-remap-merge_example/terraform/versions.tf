terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.15"
    }
  }
}

provider "datadog" {
  api_key = var.dd_api_key
  app_key = var.dd_app_key
  api_url = "https://api.datadoghq.com/"
}
