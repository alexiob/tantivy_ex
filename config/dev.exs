import Config

# Development environment configuration for TantivyEx

# Configure SASL application
config :sasl,
  sasl_error_logger: {:file, ~c'log/sasl_error.log'},
  errlog_type: :all

# Configure os_mon application for memory monitoring
config :os_mon,
  start_memsup: true,
  start_cpu_sup: false,
  start_disksup: false,
  memory_check_interval: 5000,
  system_memory_high_watermark: 0.90

# Configure TantivyEx Memory module for development
config :tantivy_ex, TantivyEx.Memory,
  max_memory_mb: 2048,
  writer_memory_mb: 1024,
  search_memory_mb: 512,
  aggregation_memory_mb: 256,
  pressure_threshold: 0.8,
  monitoring_interval_ms: 5000,
  cleanup_on_pressure: true

# Configure Logger for development
config :logger,
  level: :debug
