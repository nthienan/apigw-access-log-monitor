sources:
  apigw_access_log_queue:
    type: aws_sqs
    region: ${region}
    queue_url: ${sqs_queue_url}
    client_concurrency: 1
    decoding:
      codec: json
transforms:
  apigw_access_log_transformed:
    type: remap
    inputs:
    - apigw_access_log_queue
    source: >-
      .path, err = replace(.path, r'(\d{2,})', "{id}")
  apigw_access_log_2_metrics:
    type: log_to_metric
    inputs:
    - apigw_access_log_transformed
    metrics:
    - field: path
      name: http_request_count_total
      type: counter
      tags:
        method: "{{method}}"
        path: "{{path}}"
        status: "{{status}}"
        gatewayId: "{{gatewayId}}"
        apiKeyId: "{{apiKeyId}}"
    - field: latency
      name: http_response_latency_milliseconds
      type: histogram
      tags:
        method: "{{method}}"
        path: "{{path}}"
        status: "{{status}}"
        gatewayId: "{{gatewayId}}"
        apiKeyId: "{{apiKeyId}}"
sinks:
  apigw_aceess_log_metrics:
    type: prometheus_exporter
    inputs:
    - apigw_access_log_2_metrics
    address: 0.0.0.0:${prometheus_port}
    default_namespace: aws_apigw
    distributions_as_summaries: true
