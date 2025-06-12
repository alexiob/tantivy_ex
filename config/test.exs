import Config

# Test environment configuration for TantivyEx
# This file ensures that required applications for memory monitoring are available during tests

# Configure SASL application for proper error reporting and os_mon support
config :sasl,
  # Enable SASL error logging
  sasl_error_logger: {:file, ~c"log/sasl_error.log"},
  # Disable progress reports to reduce test noise
  errlog_type: :error

# Configure os_mon application for memory monitoring
config :os_mon,
  # Enable memory supervisor (memsup)
  start_memsup: true,
  # Disable CPU supervisor to reduce overhead
  start_cpu_sup: false,
  # Disable disk supervisor to reduce overhead
  start_disksup: false,
  # Memory check interval (in milliseconds)
  memory_check_interval: 1000,
  # Memory threshold for warnings (percentage)
  system_memory_high_watermark: 0.95

# Configure TantivyEx Memory module for testing
config :tantivy_ex, TantivyEx.Memory,
  # Default memory limits for tests
  max_memory_mb: 1024,
  writer_memory_mb: 512,
  search_memory_mb: 256,
  aggregation_memory_mb: 128,
  # Memory pressure threshold
  pressure_threshold: 0.8,
  # Monitoring interval for tests (faster for quicker feedback)
  monitoring_interval_ms: 1000,
  # Enable cleanup on memory pressure
  cleanup_on_pressure: true

# Configure Logger for test environment
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
