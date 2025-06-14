# Production Deployment

Deploying TantivyEx in production requires careful consideration of reliability, performance, monitoring, and operational concerns.

## Environment Configuration

### Index Path Management

```elixir
# config/prod.exs
config :my_app, :search_index,
  path: System.get_env("SEARCH_INDEX_PATH", "/var/lib/myapp/search_index"),
  backup_path: System.get_env("SEARCH_BACKUP_PATH", "/var/lib/myapp/search_backup")

# lib/my_app/search_config.ex
defmodule MyApp.SearchConfig do
  def index_path do
    Application.get_env(:my_app, :search_index)[:path]
  end

  def backup_path do
    Application.get_env(:my_app, :search_index)[:backup_path]
  end

  def validate_config! do
    path = index_path()
    backup = backup_path()

    unless File.exists?(Path.dirname(path)) do
      raise "Index directory does not exist: #{Path.dirname(path)}"
    end

    unless File.exists?(Path.dirname(backup)) do
      raise "Backup directory does not exist: #{Path.dirname(backup)}"
    end

    :ok
  end
end
```

### File Permissions and Security

Ensure your application has proper permissions:

```bash
# Create index directory with proper ownership
sudo mkdir -p /var/lib/myapp/search_index
sudo mkdir -p /var/lib/myapp/search_backup
sudo chown -R myapp:myapp /var/lib/myapp/
sudo chmod 755 /var/lib/myapp/search_index
sudo chmod 755 /var/lib/myapp/search_backup

# Set up log directory
sudo mkdir -p /var/log/myapp
sudo chown myapp:myapp /var/log/myapp
sudo chmod 755 /var/log/myapp
```

### Environment Variables

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :my_app, :search_index,
    path: System.fetch_env!("SEARCH_INDEX_PATH"),
    backup_path: System.fetch_env!("SEARCH_BACKUP_PATH"),
    max_memory_mb: String.to_integer(System.get_env("SEARCH_MAX_MEMORY_MB", "512")),
    commit_interval_ms: String.to_integer(System.get_env("SEARCH_COMMIT_INTERVAL_MS", "5000"))

  # Security settings
  config :my_app, :search_security,
    enable_query_logging: System.get_env("ENABLE_QUERY_LOGGING", "false") == "true",
    max_query_length: String.to_integer(System.get_env("MAX_QUERY_LENGTH", "1000")),
    rate_limit_per_minute: String.to_integer(System.get_env("SEARCH_RATE_LIMIT", "100"))
end
```

## High Availability Patterns

### Index Backup Strategy

```elixir
defmodule MyApp.SearchBackup do
  require Logger
  alias MyApp.SearchConfig

  def backup_index do
    source = SearchConfig.index_path()
    backup = SearchConfig.backup_path()
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    backup_dir = Path.join(backup, "backup_#{timestamp}")

    Logger.info("Starting index backup from #{source} to #{backup_dir}")

    case File.cp_r(source, backup_dir) do
      {:ok, _} ->
        Logger.info("Index backup completed successfully")
        clean_old_backups(backup)
        {:ok, backup_dir}

      {:error, reason} ->
        Logger.error("Index backup failed: #{inspect(reason)}")
        {:error, "Backup failed: #{reason}"}
    end
  end

  def restore_from_backup(backup_dir) do
    current_path = SearchConfig.index_path()

    Logger.warning("Restoring index from backup: #{backup_dir}")

    # Create a safety backup of current index
    safety_backup = "#{current_path}.safety_#{System.system_time(:second)}"
    File.rename(current_path, safety_backup)

    case File.cp_r(backup_dir, current_path) do
      {:ok, _} ->
        Logger.info("Index restored successfully from #{backup_dir}")
        File.rm_rf(safety_backup)
        :ok

      {:error, reason} ->
        Logger.error("Index restoration failed: #{inspect(reason)}")
        # Restore the safety backup
        File.rename(safety_backup, current_path)
        {:error, reason}
    end
  end

  defp clean_old_backups(backup_path, keep_count \\ 5) do
    try do
      backup_path
      |> File.ls!()
      |> Enum.filter(&String.starts_with?(&1, "backup_"))
      |> Enum.sort(:desc)
      |> Enum.drop(keep_count)
      |> Enum.each(fn old_backup ->
        old_path = Path.join(backup_path, old_backup)
        File.rm_rf!(old_path)
        Logger.info("Removed old backup: #{old_path}")
      end)
    rescue
      e ->
        Logger.warning("Failed to clean old backups: #{inspect(e)}")
    end
  end

  def schedule_automatic_backups do
    # Schedule daily backups at 2 AM
    Quantum.add_job(:my_app_scheduler, [
      schedule: "0 2 * * *",
      task: {__MODULE__, :backup_index, []}
    ])
  end
end
```

### Rolling Updates

```elixir
defmodule MyApp.SearchUpdater do
  require Logger

  def rolling_update(new_documents) do
    Logger.info("Starting rolling index update with #{length(new_documents)} documents")

    # 1. Create new index with updated documents
    temp_path = "/tmp/search_index_new_#{System.system_time(:second)}"

    case rebuild_index(temp_path, new_documents) do
      {:ok, new_index} ->
        # 2. Verify new index
        case verify_index(new_index) do
          :ok ->
            # 3. Atomically replace old index
            replace_index(temp_path)

          {:error, reason} ->
            Logger.error("Index verification failed: #{inspect(reason)}")
            File.rm_rf(temp_path)
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Index rebuild failed: #{inspect(reason)}")
        File.rm_rf(temp_path)
        {:error, reason}
    end
  end

  defp rebuild_index(path, documents) do
    {:ok, schema} = MyApp.Search.get_schema()

    # Remove existing index if present to ensure clean rebuild
    if File.exists?(path), do: File.rm_rf!(path)

    {:ok, index} = TantivyEx.Index.create_in_dir(path, schema)
    {:ok, writer} = TantivyEx.IndexWriter.new(index)

    # Batch insert documents
    documents
    |> Enum.chunk_every(1000)
    |> Enum.each(fn batch ->
      Enum.each(batch, &TantivyEx.IndexWriter.add_document(writer, &1))
      TantivyEx.IndexWriter.commit(writer)
    end)

    {:ok, index}
  end

  defp verify_index(index) do
    # Run verification queries
    test_queries = ["test", "verify", "sample"]

    Enum.reduce_while(test_queries, :ok, fn query, acc ->
      {:ok, searcher} = TantivyEx.Searcher.new(index)
      case TantivyEx.Searcher.search(searcher, query, 1) do
        {:ok, _} ->
          {:cont, acc}
        {:error, reason} ->
          Logger.error("Verification query failed: #{query} - #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp replace_index(new_path) do
    current_path = MyApp.SearchConfig.index_path()
    backup_path = "#{current_path}.backup.#{System.system_time(:second)}"

    Logger.info("Replacing current index with new index")

    # Atomic replacement
    case File.rename(current_path, backup_path) do
      :ok ->
        case File.rename(new_path, current_path) do
          :ok ->
            Logger.info("Index replacement completed successfully")

            # Clean up old backup after delay
            spawn(fn ->
              Process.sleep(300_000)  # Wait 5 minutes
              File.rm_rf(backup_path)
              Logger.info("Cleaned up backup: #{backup_path}")
            end)

            :ok

          {:error, reason} ->
            # Restore backup
            File.rename(backup_path, current_path)
            {:error, "Failed to move new index: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to backup current index: #{reason}"}
    end
  end
end
```

## Monitoring & Health Checks

### Comprehensive Health Check

```elixir
defmodule MyApp.SearchHealthCheck do
  require Logger
  alias TantivyEx.Index

  def health_check do
    start_time = System.monotonic_time(:millisecond)

    health_data = %{
      status: check_index_status(),
      last_update: get_last_update_time(),
      document_count: get_document_count(),
      index_size_mb: get_index_size_mb(),
      response_time_ms: nil,
      memory_usage_mb: get_memory_usage(),
      disk_space_available_mb: get_disk_space(),
      timestamp: DateTime.utc_now()
    }

    response_time = System.monotonic_time(:millisecond) - start_time
    Map.put(health_data, :response_time_ms, response_time)
  end

  def detailed_health_check do
    base_health = health_check()

    additional_checks = %{
      search_performance: measure_search_performance(),
      index_integrity: check_index_integrity(),
      backup_status: check_backup_status(),
      configuration_valid: check_configuration()
    }

    Map.merge(base_health, additional_checks)
  end

  defp check_index_status do
    index_path = MyApp.SearchConfig.index_path()
    if File.exists?(Path.join(index_path, "meta.json")) do
      :healthy
    else
      Logger.error("Index health check failed: meta.json not found")
      :unhealthy
    end
  end

  defp measure_search_performance do
    test_queries = ["test", "sample", "example"]

    results = Enum.map(test_queries, fn query ->
      start_time = System.monotonic_time(:millisecond)

      result = case MyApp.Search.simple_search(query, 1) do
        {:ok, _} -> :success
        {:error, _} -> :error
      end

      end_time = System.monotonic_time(:millisecond)

      %{
        query: query,
        result: result,
        time_ms: end_time - start_time
      }
    end)

    %{
      test_results: results,
      avg_response_time: calculate_avg_response_time(results),
      success_rate: calculate_success_rate(results)
    }
  end

  defp check_index_integrity do
    # Basic integrity checks
    path = MyApp.SearchConfig.index_path()

    %{
      directory_exists: File.exists?(path),
      directory_readable: File.dir?(path),
      has_segments: has_index_segments?(path)
    }
  end

  defp check_backup_status do
    backup_path = MyApp.SearchConfig.backup_path()

    case File.ls(backup_path) do
      {:ok, files} ->
        backups = Enum.filter(files, &String.starts_with?(&1, "backup_"))
        latest_backup = Enum.max(backups, fn -> nil end)

        %{
          backup_directory_exists: true,
          backup_count: length(backups),
          latest_backup: latest_backup,
          backup_age_hours: calculate_backup_age(latest_backup)
        }

      {:error, _} ->
        %{backup_directory_exists: false}
    end
  end

  defp check_configuration do
    try do
      MyApp.SearchConfig.validate_config!()
      true
    rescue
      _ -> false
    end
  end

  # Helper functions
  defp calculate_avg_response_time(results) do
    times = Enum.map(results, & &1.time_ms)
    Enum.sum(times) / length(times)
  end

  defp calculate_success_rate(results) do
    successes = Enum.count(results, & &1.result == :success)
    successes / length(results) * 100
  end

  defp has_index_segments?(path) do
    # Check for typical Tantivy index files
    case File.ls(path) do
      {:ok, files} ->
        Enum.any?(files, &String.contains?(&1, ".idx"))
      {:error, _} ->
        false
    end
  end

  defp calculate_backup_age(nil), do: :no_backup
  defp calculate_backup_age(backup_name) do
    # Extract timestamp from backup name
    case Regex.run(~r/backup_(\d+)/, backup_name) do
      [_, timestamp_str] ->
        timestamp = String.to_integer(timestamp_str)
        current_time = System.system_time(:second)
        (current_time - timestamp) / 3600  # Hours

      nil ->
        :unknown
    end
  end

  defp get_document_count do
    # This would need to be implemented based on your tracking strategy
    :not_implemented
  end

  defp get_index_size_mb do
    path = MyApp.SearchConfig.index_path()
    case File.stat(path) do
      {:ok, %{size: size}} -> Float.round(size / (1024 * 1024), 2)
      {:error, _} -> :unknown
    end
  end

  defp get_memory_usage do
    {:memory, memory} = :erlang.process_info(self(), :memory)
    Float.round(memory / (1024 * 1024), 2)
  end

  defp get_disk_space do
    path = MyApp.SearchConfig.index_path()
    case System.cmd("df", ["-m", path]) do
      {output, 0} ->
        # Parse df output to get available space
        lines = String.split(output, "\n")
        if length(lines) >= 2 do
          Enum.at(lines, 1)
          |> String.split()
          |> Enum.at(3)
          |> String.to_integer()
        else
          :unknown
        end

      _ -> :unknown
    end
  end

  defp get_last_update_time do
    # This should be tracked in your application state
    :not_implemented
  end
end
```

## Logging and Observability

### Search Analytics

```elixir
defmodule MyApp.SearchAnalytics do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def log_search(query, results_count, response_time_ms, user_id \\ nil) do
    GenServer.cast(__MODULE__, {
      :log_search,
      %{
        query: query,
        results_count: results_count,
        response_time_ms: response_time_ms,
        user_id: user_id,
        timestamp: DateTime.utc_now()
      }
    })
  end

  def get_analytics(timeframe \\ :last_hour) do
    GenServer.call(__MODULE__, {:get_analytics, timeframe})
  end

  # GenServer implementation
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  def handle_cast({:log_search, event}, state) do
    # Log to structured logger
    Logger.info("Search performed", [
      query: event.query,
      results_count: event.results_count,
      response_time_ms: event.response_time_ms,
      user_id: event.user_id
    ])

    # Send to telemetry
    :telemetry.execute(
      [:my_app, :search, :performed],
      %{
        response_time: event.response_time_ms,
        results_count: event.results_count
      },
      %{query: event.query}
    )

    # Store in state for analytics (with size limit)
    new_state = add_to_analytics(state, event)
    {:noreply, new_state}
  end

  def handle_call({:get_analytics, timeframe}, _from, state) do
    analytics = calculate_analytics(state, timeframe)
    {:reply, analytics, state}
  end

  def handle_info(:cleanup, state) do
    new_state = cleanup_old_events(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  # Helper functions
  defp add_to_analytics(state, event) do
    events = Map.get(state, :events, [])
    new_events = [event | events] |> Enum.take(10000)  # Keep last 10k events
    Map.put(state, :events, new_events)
  end

  defp calculate_analytics(state, timeframe) do
    events = filter_events_by_timeframe(state, timeframe)

    %{
      total_searches: length(events),
      avg_response_time: calculate_avg_response_time(events),
      avg_results_count: calculate_avg_results_count(events),
      top_queries: get_top_queries(events),
      slow_queries: get_slow_queries(events)
    }
  end

  defp filter_events_by_timeframe(state, :last_hour) do
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
    events = Map.get(state, :events, [])
    Enum.filter(events, &DateTime.after?(&1.timestamp, cutoff))
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 3600_000)  # Every hour
  end

  defp cleanup_old_events(state) do
    # Remove events older than 24 hours
    cutoff = DateTime.add(DateTime.utc_now(), -86400, :second)
    events = Map.get(state, :events, [])
    new_events = Enum.filter(events, &DateTime.after?(&1.timestamp, cutoff))
    Map.put(state, :events, new_events)
  end
end
```

## Security Considerations

### Query Validation and Sanitization

```elixir
defmodule MyApp.SearchSecurity do
  @max_query_length 1000
  @rate_limit_per_minute 100

  def validate_query(query) do
    with :ok <- check_query_length(query),
         :ok <- check_query_syntax(query),
         :ok <- check_rate_limit() do
      {:ok, sanitize_query(query)}
    end
  end

  defp check_query_length(query) when byte_size(query) > @max_query_length do
    {:error, :query_too_long}
  end
  defp check_query_length(_query), do: :ok

  defp check_query_syntax(query) do
    # Basic syntax validation
    forbidden_patterns = [
      ~r/\.\./,           # Directory traversal
      ~r/[<>]/,          # Potential injection
      ~r/\\\\/           # Path separators
    ]

    if Enum.any?(forbidden_patterns, &Regex.match?(&1, query)) do
      {:error, :invalid_query_syntax}
    else
      :ok
    end
  end

  defp check_rate_limit do
    # Implement rate limiting logic
    # This could use a GenServer, ETS, or external store like Redis
    :ok
  end

  defp sanitize_query(query) do
    query
    |> String.trim()
    |> String.slice(0, @max_query_length)
  end
end
```

## Deployment Checklist

### Pre-deployment

- [ ] Index directory permissions configured
- [ ] Backup strategy implemented
- [ ] Health checks configured
- [ ] Monitoring and logging set up
- [ ] Security validations in place
- [ ] Performance benchmarks established

### During deployment

- [ ] Gradual rollout with canary testing
- [ ] Monitor system resources
- [ ] Verify search functionality
- [ ] Check backup creation
- [ ] Validate health endpoints

### Post-deployment

- [ ] Monitor search performance
- [ ] Review error logs
- [ ] Validate backup schedule
- [ ] Check disk space usage
- [ ] Monitor query patterns

This production deployment guide provides a solid foundation for running TantivyEx reliably in production environments with proper monitoring, backup strategies, and security considerations.

## Index Initialization Strategy

### Production-Ready Index Management

For production applications, use the `open_or_create/2` function which provides robust index management:

```elixir
defmodule MyApp.Search.IndexManager do
  require Logger
  alias TantivyEx.Index

  def init_index do
    path = Application.get_env(:my_app, :search_index)[:path]

    case ensure_index_directory(path) do
      :ok ->
        Logger.info("Initializing search index at #{path}")
        {:ok, schema} = build_schema()

        # This will open existing index or create new one
        case Index.open_or_create(path, schema) do
          {:ok, index} ->
            Logger.info("Search index ready")
            {:ok, index}

          {:error, reason} ->
            Logger.error("Failed to initialize index: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Index directory setup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_index_directory(path) do
    dir = Path.dirname(path)

    case File.mkdir_p(dir) do
      :ok ->
        Logger.debug("Index directory ready: #{dir}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create index directory: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_schema do
    # Define your schema here
    schema = TantivyEx.Schema.new()
    schema = TantivyEx.Schema.add_text_field(schema, "title", :text_stored)
    schema = TantivyEx.Schema.add_text_field(schema, "content", :text)
    # ... add other fields
    {:ok, schema}
  end
end
```

### Index Function Comparison

Choose the right function for your use case:

| Function | Use Case | Behavior |
|----------|----------|----------|
| `create_in_dir/2` | New deployments | Creates new index, fails if exists |
| `open/1` | Existing index only | Opens existing, fails if missing |
| `open_or_create/2` | **Production recommended** | Opens existing or creates new |
| `create_in_ram/1` | Testing/temporary | Creates in-memory index |

### Error Handling

```elixir
defmodule MyApp.Search.SafeInitializer do
  require Logger

  def safe_init_index(path, schema, max_retries \\ 3) do
    safe_init_index(path, schema, max_retries, 1)
  end

  defp safe_init_index(path, schema, max_retries, attempt) when attempt <= max_retries do
    case TantivyEx.Index.open_or_create(path, schema) do
      {:ok, index} ->
        Logger.info("Index initialized successfully on attempt #{attempt}")
        {:ok, index}

      {:error, reason} ->
        Logger.warning("Index init attempt #{attempt} failed: #{inspect(reason)}")

        if attempt < max_retries do
          :timer.sleep(1000 * attempt)  # Exponential backoff
          safe_init_index(path, schema, max_retries, attempt + 1)
        else
          Logger.error("Index initialization failed after #{max_retries} attempts")
          {:error, "Max retries exceeded: #{inspect(reason)}"}
        end
    end
  end
end
```
