resource "datadog_observability_pipeline" "opw_demo" {
  config {
    destination {
      datadog_logs {
      }
      id     = "dd-logs-out"
      inputs = ["reduce-group"]
    }
    pipeline_type = "logs"
    processor_group {
      display_name = "reduce-group"
      enabled      = false
      id           = "reduce-group"
      include      = "*"
      inputs       = ["dd-agent-in"]
      processor {
        display_name = "Split Arrays"
        enabled      = false
        id           = "processor-d11f284a-cc36-4f81-ac1b-b618043a9cd8"
        include      = "*"
        split_array {
          array {
            field   = "ongoing"
            include = "source:opw-api-demo"
          }
        }
      }
      processor {
        display_name = "Edit Fields"
        enabled      = false
        id           = "processor-37b6b5e9-7bb8-4706-92a1-18a328edb2ce"
        include      = "source:opw-api-demo"
        rename_fields {
          field {
            destination     = "record_id"
            preserve_source = true
            source          = "ongoing.record_id"
          }
        }
      }
      processor {
        display_name = "reduce-by-record-id"
        enabled      = false
        id           = "reduce-by-record-id"
        include      = "*"
        reduce {
          group_by = ["record_id"]
          merge_strategy {
            path     = "record_id"
            strategy = "discard"
          }
        }
      }
    }
    source {
      http_server {
        auth_strategy = "none"
        decoding      = "json"
      }
      id = "dd-agent-in"
    }
  }
  name = "opw-demo"
}

