global:
  scrape_interval:     15s
  evaluation_interval: 15s

scrape_configs:
- job_name: apigw-access-log
  scrape_interval: 15s
  static_configs:
  - targets: [${vector_alb_dns_name}:${vector_prometheus_port}]
