output "pipeline_id" {
  value       = datadog_observability_pipeline.api_demo.id
  description = "Pass to OPW as DD_OP_PIPELINE_ID"
}
