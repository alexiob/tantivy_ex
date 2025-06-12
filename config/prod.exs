import Config

# Production environment configuration for TantivyEx

# Configure SASL application for production
config :sasl,
  sasl_error_logger: {:file, ~c'log/sasl_error.log'},
  errlog_type: :error

# Configure os_mon application for memory monitoring in production
config :os_mon,
  start_memsup: true,
  start_cpu_sup: true,
  start_disksup: true,
  memory_check_interval: 10000,
  system_memory_high_watermark: 0.85

# Configure TantivyEx Memory module for production
config :tantivy_ex, TantivyEx.Memory,
  max_memory_mb: 4096,
  writer_memory_mb: 2048,
  search_memory_mb: 1024,
  aggregation_memory_mb: 512,
  pressure_threshold: 0.75,
  monitoring_interval_ms: 10000,
  cleanup_on_pressure: true

# Configure Logger for production
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
