defmodule TantivyEx.Aggregation do
  @moduledoc """
  Comprehensive aggregation functionality for TantivyEx with Elasticsearch-compatible API.

  This module provides a complete aggregation system supporting:
  - Bucket aggregations (terms, histogram, date_histogram, range)
  - Metric aggregations (avg, min, max, sum, count, stats, percentiles)
  - Nested/sub-aggregations
  - Elasticsearch-compatible JSON request/response format
  - Advanced aggregation options and configurations

  ## Features

  ### Bucket Aggregations
  - **Terms**: Group documents by field values
  - **Histogram**: Group numeric values into buckets with fixed intervals
  - **Date Histogram**: Group date values into time-based buckets
  - **Range**: Group documents into custom value ranges

  ### Metric Aggregations
  - **Average**: Calculate average value of a numeric field
  - **Min/Max**: Find minimum/maximum values
  - **Sum**: Calculate sum of numeric field values
  - **Count**: Count documents (value count aggregation)
  - **Stats**: Calculate min, max, sum, count, and average in one aggregation
  - **Percentiles**: Calculate percentile values (50th, 95th, 99th, etc.)

  ### Advanced Features
  - **Nested Aggregations**: Add sub-aggregations to bucket aggregations
  - **Memory Optimization**: Built-in memory limits and performance optimizations
  - **Elasticsearch Compatibility**: Request/response format matches Elasticsearch
  - **Error Handling**: Comprehensive validation and error reporting

  ## Usage Examples

      # Simple terms aggregation
      aggregations = %{
        "categories" => %{
          "terms" => %{
            "field" => "category",
            "size" => 10
          }
        }
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      # Histogram with sub-aggregation
      aggregations = %{
        "price_histogram" => %{
          "histogram" => %{
            "field" => "price",
            "interval" => 10.0
          },
          "aggs" => %{
            "avg_rating" => %{
              "avg" => %{
                "field" => "rating"
              }
            }
          }
        }
      }

      # Date histogram
      aggregations = %{
        "sales_over_time" => %{
          "date_histogram" => %{
            "field" => "timestamp",
            "calendar_interval" => "month"
          }
        }
      }

      # Range aggregation
      aggregations = %{
        "price_ranges" => %{
          "range" => %{
            "field" => "price",
            "ranges" => [
              %{"to" => 50},
              %{"from" => 50, "to" => 100},
              %{"from" => 100}
            ]
          }
        }
      }

      # Multiple aggregations
      aggregations = %{
        "avg_price" => %{
          "avg" => %{"field" => "price"}
        },
        "max_price" => %{
          "max" => %{"field" => "price"}
        },
        "price_stats" => %{
          "stats" => %{"field" => "price"}
        }
      }

      # Search with aggregations
      {:ok, result} = Aggregation.search_with_aggregations(searcher, query, aggregations, 20)
  """

  alias TantivyEx.Native

  @type aggregation_request :: map()
  @type aggregation_result :: map()
  @type aggregation_options :: [
          validate: boolean(),
          memory_limit: pos_integer(),
          timeout: pos_integer()
        ]

  @default_options [
    validate: true,
    memory_limit: 100_000_000,
    timeout: 30_000
  ]

  @doc """
  Runs aggregations on search results without returning documents.

  ## Parameters

  - `searcher`: SearcherResource from TantivyEx.Searcher
  - `query`: QueryResource from TantivyEx.Query
  - `aggregations`: Map of aggregation definitions
  - `options`: Aggregation options (optional)

  ## Returns

  - `{:ok, aggregation_results}` on success
  - `{:error, reason}` on failure

  ## Examples

      aggregations = %{
        "categories" => %{
          "terms" => %{
            "field" => "category",
            "size" => 10
          }
        }
      }

      {:ok, results} = Aggregation.run(searcher, query, aggregations)

      # Results format:
      %{
        "categories" => %{
          "doc_count_error_upper_bound" => 0,
          "sum_other_doc_count" => 0,
          "buckets" => [
            %{"key" => "electronics", "doc_count" => 150},
            %{"key" => "books", "doc_count" => 89}
          ]
        }
      }
  """
  @spec run(term(), term(), aggregation_request(), aggregation_options()) ::
          {:ok, aggregation_result()} | {:error, String.t()}
  def run(searcher, query, aggregations, options \\ []) do
    opts = Keyword.merge(@default_options, options)

    with {:ok, validated_aggs} <- validate_aggregations(aggregations, opts),
         {:ok, json_request} <- encode_aggregations(validated_aggs),
         {:ok, json_response} <- run_native_aggregations(searcher, query, json_request),
         {:ok, result} <- decode_aggregation_result(json_response) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs a search query with aggregations, returning both hits and aggregation results.

  ## Parameters

  - `searcher`: SearcherResource from TantivyEx.Searcher
  - `query`: QueryResource from TantivyEx.Query
  - `aggregations`: Map of aggregation definitions
  - `search_limit`: Maximum number of documents to return (default: 10)
  - `options`: Aggregation options (optional)

  ## Returns

  - `{:ok, %{hits: search_results, aggregations: aggregation_results}}` on success
  - `{:error, reason}` on failure

  ## Examples

      aggregations = %{
        "avg_price" => %{
          "avg" => %{"field" => "price"}
        }
      }

      {:ok, result} = Aggregation.search_with_aggregations(searcher, query, aggregations, 20)

      # Result format:
      %{
        "hits" => %{
          "total" => 150,
          "hits" => [
            %{"score" => 1.5, "doc_id" => 1, "title" => "Product 1", ...},
            ...
          ]
        },
        "aggregations" => %{
          "avg_price" => %{"value" => 29.99}
        }
      }
  """
  @spec search_with_aggregations(
          term(),
          term(),
          aggregation_request(),
          non_neg_integer(),
          aggregation_options()
        ) ::
          {:ok, map()} | {:error, String.t()}
  def search_with_aggregations(searcher, query, aggregations, search_limit \\ 10, options \\ []) do
    opts = Keyword.merge(@default_options, options)

    with {:ok, validated_aggs} <- validate_aggregations(aggregations, opts),
         {:ok, json_request} <- encode_aggregations(validated_aggs),
         {:ok, json_response} <-
           run_native_search_with_aggregations(searcher, query, json_request, search_limit),
         {:ok, result} <- decode_search_with_aggregations_result(json_response) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a terms aggregation for grouping documents by field values.

  ## Parameters

  - `field`: Field name to aggregate on
  - `options`: Terms aggregation options

  ## Options

  - `:size` - Maximum number of buckets to return (default: 10)
  - `:min_doc_count` - Minimum document count for buckets (default: 1)
  - `:missing` - Value to use for documents missing the field
  - `:order` - Sort order for buckets

  ## Examples

      terms_agg = Aggregation.terms("category", size: 20, min_doc_count: 5)
      # Returns: %{"terms" => %{"field" => "category", "size" => 20, "min_doc_count" => 5}}
  """
  @spec terms(String.t(), keyword()) :: map()
  def terms(field, options \\ []) do
    base_config = %{
      "field" => field,
      "size" => Keyword.get(options, :size, 10)
    }

    config = add_optional_params(base_config, options, [:min_doc_count, :missing, :order])
    %{"terms" => config}
  end

  @doc """
  Creates a histogram aggregation for grouping numeric values into fixed-interval buckets.

  ## Parameters

  - `field`: Numeric field name to aggregate on
  - `interval`: Bucket interval size
  - `options`: Histogram aggregation options

  ## Options

  - `:min_doc_count` - Minimum document count for buckets (default: 1)
  - `:keyed` - Return buckets as a map instead of array (default: false)

  ## Examples

      hist_agg = Aggregation.histogram("price", 10.0, min_doc_count: 2)
      # Returns: %{"histogram" => %{"field" => "price", "interval" => 10.0, "min_doc_count" => 2}}
  """
  @spec histogram(String.t(), float(), keyword()) :: map()
  def histogram(field, interval, options \\ []) do
    base_config = %{
      "field" => field,
      "interval" => interval
    }

    config = add_optional_params(base_config, options, [:min_doc_count, :keyed])
    %{"histogram" => config}
  end

  @doc """
  Creates a date histogram aggregation for grouping date values into time-based buckets.

  ## Parameters

  - `field`: Date field name to aggregate on
  - `interval`: Time interval (e.g., "day", "month", "year", "1h", "30m")
  - `options`: Date histogram aggregation options

  ## Options

  - `:min_doc_count` - Minimum document count for buckets (default: 1)
  - `:keyed` - Return buckets as a map instead of array (default: false)
  - `:time_zone` - Time zone for bucket calculation
  - `:format` - Date format for bucket keys

  ## Examples

      date_hist = Aggregation.date_histogram("timestamp", "month")
      # Returns: %{"date_histogram" => %{"field" => "timestamp", "calendar_interval" => "month"}}

      hourly_hist = Aggregation.date_histogram("created_at", "1h", time_zone: "America/New_York")
  """
  @spec date_histogram(String.t(), String.t(), keyword()) :: map()
  def date_histogram(field, interval, options \\ []) do
    base_config = %{
      "field" => field,
      "calendar_interval" => interval
    }

    config =
      add_optional_params(base_config, options, [:min_doc_count, :keyed, :time_zone, :format])

    %{"date_histogram" => config}
  end

  @doc """
  Creates a range aggregation for grouping documents into custom value ranges.

  ## Parameters

  - `field`: Numeric field name to aggregate on
  - `ranges`: List of range specifications
  - `options`: Range aggregation options

  ## Range Specifications

  Each range can have:
  - `:from` - Lower bound (inclusive)
  - `:to` - Upper bound (exclusive)
  - `:key` - Custom key name for the bucket

  ## Options

  - `:keyed` - Return buckets as a map instead of array (default: false)

  ## Examples

      ranges = [
        %{"to" => 50},
        %{"from" => 50, "to" => 100, "key" => "medium"},
        %{"from" => 100}
      ]
      range_agg = Aggregation.range("price", ranges)

      # Using helper
      range_agg = Aggregation.range("price", [
        {nil, 50},
        {50, 100, "medium"},
        {100, nil}
      ])
  """
  @spec range(String.t(), [map()] | [tuple()], keyword()) :: map()
  def range(field, ranges, options \\ []) do
    normalized_ranges = normalize_ranges(ranges)

    base_config = %{
      "field" => field,
      "ranges" => normalized_ranges
    }

    config = add_optional_params(base_config, options, [:keyed])
    %{"range" => config}
  end

  @doc """
  Creates a metric aggregation for calculating statistics on numeric fields.

  ## Parameters

  - `type`: Type of metric (:avg, :min, :max, :sum, :count, :stats, :percentiles)
  - `field`: Field name to calculate metrics on
  - `options`: Metric-specific options

  ## Metric Types

  - `:avg` - Average value
  - `:min` - Minimum value
  - `:max` - Maximum value
  - `:sum` - Sum of all values
  - `:count` - Count of values
  - `:stats` - All basic statistics (min, max, avg, sum, count)
  - `:percentiles` - Percentile calculations

  ## Options for :percentiles

  - `:percents` - List of percentiles to calculate (default: [1, 5, 25, 50, 75, 95, 99])
  - `:keyed` - Return as map instead of array (default: true)

  ## Examples

      avg_agg = Aggregation.metric(:avg, "price")
      # Returns: %{"avg" => %{"field" => "price"}}

      stats_agg = Aggregation.metric(:stats, "rating")
      # Returns: %{"stats" => %{"field" => "rating"}}

      percentiles_agg = Aggregation.metric(:percentiles, "response_time", percents: [50, 95, 99])
  """
  @spec metric(atom(), String.t(), keyword()) :: map()
  def metric(type, field, options \\ [])

  def metric(:percentiles, field, options) do
    base_config = %{
      "field" => field,
      "percents" => Keyword.get(options, :percents, [1.0, 5.0, 25.0, 50.0, 75.0, 95.0, 99.0]),
      "keyed" => Keyword.get(options, :keyed, true)
    }

    config = add_optional_params(base_config, options, [:missing])
    %{"percentiles" => config}
  end

  def metric(type, field, options) when type in [:avg, :min, :max, :sum, :count, :stats] do
    base_config = %{"field" => field}
    config = add_optional_params(base_config, options, [:missing])
    %{Atom.to_string(type) => config}
  end

  @doc """
  Adds sub-aggregations to a bucket aggregation.

  ## Parameters

  - `aggregation`: Base bucket aggregation
  - `sub_aggregations`: Map of sub-aggregation definitions

  ## Examples

      base_agg = Aggregation.terms("category", size: 10)

      sub_aggs = %{
        "avg_price" => Aggregation.metric(:avg, "price"),
        "max_rating" => Aggregation.metric(:max, "rating")
      }

      full_agg = Aggregation.with_sub_aggregations(base_agg, sub_aggs)
  """
  @spec with_sub_aggregations(map(), map()) :: map()
  def with_sub_aggregations(aggregation, sub_aggregations) when is_map(sub_aggregations) do
    Map.put(aggregation, "aggs", sub_aggregations)
  end

  @doc """
  Creates a complete aggregation request with multiple aggregations.

  ## Parameters

  - `aggregations`: Map or keyword list of aggregation definitions

  ## Examples

      aggs = Aggregation.build_request([
        {"categories", Aggregation.terms("category", size: 20)},
        {"avg_price", Aggregation.metric(:avg, "price")},
        {"price_histogram", Aggregation.histogram("price", 10.0)}
      ])

      # Or with a map
      aggs = Aggregation.build_request(%{
        "categories" => Aggregation.terms("category"),
        "stats" => Aggregation.metric(:stats, "price")
      })
  """
  @spec build_request(map() | keyword()) :: map()
  def build_request(aggregations) when is_map(aggregations), do: aggregations

  def build_request(aggregations) when is_list(aggregations) do
    Enum.into(aggregations, %{})
  end

  # Private helper functions

  defp validate_aggregations(aggregations, opts) do
    if Keyword.get(opts, :validate, true) do
      validate_aggregation_structure(aggregations)
    else
      {:ok, aggregations}
    end
  end

  defp validate_aggregation_structure(aggregations) when is_map(aggregations) do
    try do
      # Basic structure validation
      for {name, agg_def} <- aggregations do
        unless is_binary(name) do
          throw({:error, "Aggregation names must be strings, got: #{inspect(name)}"})
        end

        unless is_map(agg_def) do
          throw({:error, "Aggregation definition must be a map, got: #{inspect(agg_def)}"})
        end

        validate_single_aggregation(agg_def)
      end

      {:ok, aggregations}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_aggregation_structure(_) do
    {:error, "Aggregations must be a map"}
  end

  defp validate_single_aggregation(agg_def) do
    # Find aggregation type (skip 'aggs' and 'aggregations' keys)
    agg_types = Map.keys(agg_def) -- ["aggs", "aggregations"]

    case agg_types do
      [] ->
        throw({:error, "No aggregation type found in definition"})

      [agg_type] ->
        validate_aggregation_type(agg_type, Map.get(agg_def, agg_type))

      multiple ->
        throw({:error, "Multiple aggregation types found: #{inspect(multiple)}"})
    end

    # Validate sub-aggregations if present
    if sub_aggs = agg_def["aggs"] || agg_def["aggregations"] do
      validate_aggregation_structure(sub_aggs)
    end
  end

  defp validate_aggregation_type(type, config)
       when type in ["terms", "histogram", "date_histogram", "range"] do
    unless Map.has_key?(config, "field") do
      throw({:error, "#{type} aggregation requires 'field' parameter"})
    end

    case type do
      "histogram" ->
        unless Map.has_key?(config, "interval") do
          throw({:error, "histogram aggregation requires 'interval' parameter"})
        end

      "date_histogram" ->
        unless Map.has_key?(config, "calendar_interval") or Map.has_key?(config, "fixed_interval") do
          throw(
            {:error,
             "date_histogram aggregation requires 'calendar_interval' or 'fixed_interval' parameter"}
          )
        end

      "range" ->
        unless Map.has_key?(config, "ranges") and is_list(config["ranges"]) do
          throw({:error, "range aggregation requires 'ranges' parameter as a list"})
        end

      _ ->
        :ok
    end
  end

  defp validate_aggregation_type(type, config)
       when type in ["avg", "min", "max", "sum", "count", "stats", "percentiles"] do
    unless Map.has_key?(config, "field") do
      throw({:error, "#{type} aggregation requires 'field' parameter"})
    end
  end

  defp validate_aggregation_type(type, _config) do
    throw({:error, "Unknown aggregation type: #{type}"})
  end

  defp encode_aggregations(aggregations) do
    case Jason.encode(aggregations) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to encode aggregations: #{inspect(reason)}"}
    end
  end

  defp decode_aggregation_result(json_response) do
    case Jason.decode(json_response) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Failed to decode aggregation result: #{inspect(reason)}"}
    end
  end

  defp decode_search_with_aggregations_result(json_response) do
    case Jason.decode(json_response) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Failed to decode search with aggregations result: #{inspect(reason)}"}
    end
  end

  defp run_native_aggregations(searcher, query, json_request) do
    case Native.run_aggregations(searcher, query, json_request) do
      result when is_binary(result) ->
        if String.starts_with?(result, "Error") do
          {:error, result}
        else
          {:ok, result}
        end

      error ->
        {:error, "Native aggregation call failed: #{inspect(error)}"}
    end
  end

  defp run_native_search_with_aggregations(searcher, query, json_request, search_limit) do
    case Native.run_search_with_aggregations(searcher, query, json_request, search_limit) do
      result when is_binary(result) ->
        if String.starts_with?(result, "Error") do
          {:error, result}
        else
          {:ok, result}
        end

      error ->
        {:error, "Native search with aggregations call failed: #{inspect(error)}"}
    end
  end

  defp add_optional_params(config, options, param_names) do
    Enum.reduce(param_names, config, fn param, acc ->
      case Keyword.get(options, param) do
        nil -> acc
        value -> Map.put(acc, Atom.to_string(param), value)
      end
    end)
  end

  defp normalize_ranges(ranges) when is_list(ranges) do
    Enum.map(ranges, &normalize_single_range/1)
  end

  defp normalize_single_range(%{} = range), do: range

  defp normalize_single_range({from, to}) do
    %{}
    |> add_if_not_nil("from", from)
    |> add_if_not_nil("to", to)
  end

  defp normalize_single_range({from, to, key}) do
    %{}
    |> add_if_not_nil("from", from)
    |> add_if_not_nil("to", to)
    |> add_if_not_nil("key", key)
  end

  defp add_if_not_nil(map, _key, nil), do: map
  defp add_if_not_nil(map, key, value), do: Map.put(map, key, value)
end
