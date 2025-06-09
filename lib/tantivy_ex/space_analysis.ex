defmodule TantivyEx.SpaceAnalysis do
  @moduledoc """
  Space usage analysis and optimization recommendations for TantivyEx indexes.

  This module provides comprehensive analysis of index space usage, including
  segment breakdown, field-level analysis, and optimization recommendations.

  ## Features

  - Detailed space usage analysis by segments and fields
  - Storage breakdown by component type (postings, terms, fast fields, etc.)
  - Comparison between different analysis snapshots
  - Optimization recommendations based on usage patterns
  - Caching for expensive analysis operations

  ## Usage

      # Create a space analysis resource
      {:ok, analyzer} = TantivyEx.SpaceAnalysis.new()

      # Configure analysis settings
      :ok = TantivyEx.SpaceAnalysis.configure(analyzer, %{
        include_file_details: true,
        include_field_breakdown: true,
        cache_results: true,
        cache_ttl_seconds: 300
      })

      # Analyze an index
      {:ok, analysis} = TantivyEx.SpaceAnalysis.analyze_index(analyzer, index, "snapshot_1")

      # Get optimization recommendations
      {:ok, recommendations} = TantivyEx.SpaceAnalysis.get_recommendations(analyzer, "snapshot_1")

      # Compare two analyses
      {:ok, comparison} = TantivyEx.SpaceAnalysis.compare(analyzer, "snapshot_1", "snapshot_2")
  """

  alias TantivyEx.Native

  @type analysis_resource :: reference()
  @type index_resource :: reference()

  @type analysis_config :: %{
          include_file_details: boolean(),
          include_field_breakdown: boolean(),
          cache_results: boolean(),
          cache_ttl_seconds: pos_integer()
        }

  @type space_analysis :: %{
          total_size_bytes: non_neg_integer(),
          segment_count: non_neg_integer(),
          segments: [segment_analysis()],
          field_analysis: %{String.t() => field_space_usage()},
          index_metadata: index_metadata(),
          storage_breakdown: storage_breakdown()
        }

  @type segment_analysis :: %{
          segment_id: String.t(),
          size_bytes: non_neg_integer(),
          doc_count: non_neg_integer(),
          deleted_docs: non_neg_integer(),
          compression_ratio: float(),
          files: [segment_file()]
        }

  @type segment_file :: %{
          file_type: String.t(),
          file_name: String.t(),
          size_bytes: non_neg_integer(),
          percentage_of_segment: float()
        }

  @type field_space_usage :: %{
          field_name: String.t(),
          total_size_bytes: non_neg_integer(),
          indexed_size_bytes: non_neg_integer(),
          stored_size_bytes: non_neg_integer(),
          fast_fields_size_bytes: non_neg_integer(),
          percentage_of_index: float()
        }

  @type index_metadata :: %{
          total_docs: non_neg_integer(),
          deleted_docs: non_neg_integer(),
          schema_size_bytes: non_neg_integer(),
          num_fields: non_neg_integer(),
          index_settings: %{String.t() => String.t()}
        }

  @type storage_breakdown :: %{
          postings: non_neg_integer(),
          term_dictionary: non_neg_integer(),
          fast_fields: non_neg_integer(),
          field_norms: non_neg_integer(),
          stored_fields: non_neg_integer(),
          positions: non_neg_integer(),
          delete_bitset: non_neg_integer(),
          other: non_neg_integer()
        }

  @type recommendation :: %{
          type: String.t(),
          priority: String.t(),
          description: String.t(),
          potential_savings_bytes: non_neg_integer()
        }

  @doc """
  Create a new space analysis resource.

  ## Returns

  - `{:ok, analysis_resource}` - A new analysis resource
  - `{:error, reason}` - If creation fails

  ## Examples

      {:ok, analyzer} = TantivyEx.SpaceAnalysis.new()
  """
  @spec new() :: {:ok, analysis_resource()} | {:error, term()}
  def new do
    case Native.space_analysis_new() do
      resource when is_reference(resource) -> {:ok, resource}
      error -> {:error, error}
    end
  end

  @doc """
  Configure space analysis settings.

  ## Parameters

  - `analysis_resource` - The analysis resource
  - `config` - Configuration map with analysis settings

  ## Configuration Options

  - `:include_file_details` - Include detailed file breakdown (default: true)
  - `:include_field_breakdown` - Include per-field analysis (default: true)
  - `:cache_results` - Cache analysis results (default: true)
  - `:cache_ttl_seconds` - Cache TTL in seconds (default: 300)

  ## Returns

  - `:ok` - If configuration succeeds
  - `{:error, reason}` - If configuration fails

  ## Examples

      :ok = TantivyEx.SpaceAnalysis.configure(analyzer, %{
        include_file_details: true,
        include_field_breakdown: true,
        cache_results: true,
        cache_ttl_seconds: 600
      })
  """
  @spec configure(analysis_resource(), analysis_config()) :: :ok | {:error, term()}
  def configure(analysis_resource, config) do
    include_file_details = Map.get(config, :include_file_details, true)
    include_field_breakdown = Map.get(config, :include_field_breakdown, true)
    cache_results = Map.get(config, :cache_results, true)
    cache_ttl_seconds = Map.get(config, :cache_ttl_seconds, 300)

    case Native.space_analysis_configure(
           analysis_resource,
           include_file_details,
           include_field_breakdown,
           cache_results,
           cache_ttl_seconds
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Analyze space usage for an index.

  Performs comprehensive analysis of index space usage including segments,
  fields, and storage breakdown.

  ## Parameters

  - `analysis_resource` - The analysis resource
  - `index_resource` - The index to analyze
  - `analysis_id` - Unique identifier for this analysis

  ## Returns

  - `{:ok, analysis}` - Space analysis results
  - `{:error, reason}` - If analysis fails

  ## Examples

      {:ok, analysis} = TantivyEx.SpaceAnalysis.analyze_index(analyzer, index, "daily_snapshot")
      # Returns detailed space analysis with size and field information
  """
  @spec analyze_index(analysis_resource(), index_resource(), String.t()) ::
          {:ok, space_analysis()} | {:error, term()}
  def analyze_index(analysis_resource, index_resource, analysis_id) when is_binary(analysis_id) do
    case Native.space_analysis_analyze_index(analysis_resource, index_resource, analysis_id) do
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string, keys: :atoms) do
          {:ok, analysis} -> {:ok, analysis}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      error ->
        {:error, error}
    end
  end

  @doc """
  Get cached analysis results.

  Retrieves previously cached analysis results if available.

  ## Parameters

  - `analysis_resource` - The analysis resource
  - `analysis_id` - The analysis identifier

  ## Returns

  - `{:ok, analysis_summary}` - If cached results are found
  - `{:error, :not_found}` - If no cached results exist
  - `{:error, reason}` - If retrieval fails

  ## Examples

      case TantivyEx.SpaceAnalysis.get_cached(analyzer, "daily_snapshot") do
        {:ok, summary} ->
          IO.puts("Found cached analysis: \#{summary.total_size_bytes} bytes")

        {:error, :not_found} ->
          # Run new analysis
          TantivyEx.SpaceAnalysis.analyze_index(analyzer, index, "daily_snapshot")
      end
  """
  @spec get_cached(analysis_resource(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_cached(analysis_resource, analysis_id) when is_binary(analysis_id) do
    case Native.space_analysis_get_cached(analysis_resource, analysis_id) do
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string, keys: :atoms) do
          {:ok, %{found: true, analysis: analysis}} -> {:ok, analysis}
          {:ok, %{found: false}} -> {:error, :not_found}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      error ->
        {:error, error}
    end
  end

  @doc """
  Compare space usage between two analyses.

  Provides detailed comparison showing changes in size, segments, and documents.

  ## Parameters

  - `analysis_resource` - The analysis resource
  - `analysis_id_1` - First analysis identifier
  - `analysis_id_2` - Second analysis identifier

  ## Returns

  - `{:ok, comparison}` - Comparison results
  - `{:error, reason}` - If comparison fails

  ## Examples

      {:ok, comparison} = TantivyEx.SpaceAnalysis.compare(analyzer, "before", "after")

      IO.puts("Size change: \#{comparison.comparison.size_difference_bytes} bytes")
      IO.puts("Change %: \#{comparison.comparison.size_change_percentage}%")
  """
  @spec compare(analysis_resource(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def compare(analysis_resource, analysis_id_1, analysis_id_2)
      when is_binary(analysis_id_1) and is_binary(analysis_id_2) do
    case Native.space_analysis_compare(analysis_resource, analysis_id_1, analysis_id_2) do
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string, keys: :atoms) do
          {:ok, comparison} -> {:ok, comparison}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      error ->
        {:error, error}
    end
  rescue
    e in ArgumentError -> {:error, "Invalid arguments for compare: #{inspect(e)}"}
    e -> {:error, "Failed to compare analyses: #{inspect(e)}"}
  end

  @doc """
  Get optimization recommendations based on analysis.

  Analyzes space usage patterns and provides actionable recommendations
  for optimizing index storage.

  ## Parameters

  - `analysis_resource` - The analysis resource
  - `analysis_id` - The analysis identifier

  ## Returns

  - `{:ok, recommendations}` - List of optimization recommendations
  - `{:error, reason}` - If analysis fails

  ## Recommendation Types

  - `merge_segments` - Reduce segment count through merging
  - `optimize_deletes` - Clean up deleted documents
  - `field_optimization` - Optimize field storage settings

  ## Examples

      {:ok, %{recommendations: recs}} = TantivyEx.SpaceAnalysis.get_recommendations(analyzer, "snapshot")

      for rec <- recs do
        IO.puts("\#{rec.priority}: \#{rec.description}")
        IO.puts("Potential savings: \#{rec.potential_savings_bytes} bytes")
      end
  """
  @spec get_recommendations(analysis_resource(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_recommendations(analysis_resource, analysis_id) when is_binary(analysis_id) do
    case Native.space_analysis_get_recommendations(analysis_resource, analysis_id) do
      json_string when is_binary(json_string) ->
        case Jason.decode(json_string, keys: :atoms) do
          {:ok, recommendations} -> {:ok, recommendations}
          {:error, reason} -> {:error, {:json_decode_error, reason}}
        end

      error ->
        {:error, error}
    end
  rescue
    e in ArgumentError -> {:error, "Invalid arguments for get_recommendations: #{inspect(e)}"}
    e -> {:error, "Failed to get recommendations: #{inspect(e)}"}
  end

  @doc """
  Clear the analysis cache.

  Removes all cached analysis results to free memory.

  ## Parameters

  - `analysis_resource` - The analysis resource

  ## Returns

  - `:ok` - If cache is cleared successfully
  - `{:error, reason}` - If clearing fails

  ## Examples

      :ok = TantivyEx.SpaceAnalysis.clear_cache(analyzer)
  """
  @spec clear_cache(analysis_resource()) :: :ok | {:error, term()}
  def clear_cache(analysis_resource) do
    case Native.space_analysis_clear_cache(analysis_resource) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @doc """
  Get space efficiency metrics.

  Convenience function to extract key efficiency indicators from analysis.

  ## Parameters

  - `analysis` - Space analysis results

  ## Returns

  - `{:ok, metrics}` - Efficiency metrics

  ## Examples

      {:ok, analysis} = TantivyEx.SpaceAnalysis.analyze_index(analyzer, index, "test")
      {:ok, metrics} = TantivyEx.SpaceAnalysis.get_efficiency_metrics(analysis)
      # %{space_per_doc: 1024.5, compression_ratio: 0.75, deletion_ratio: 0.05}
  """
  @spec get_efficiency_metrics(space_analysis()) :: {:ok, map()}
  def get_efficiency_metrics(analysis) do
    space_per_doc =
      if analysis.index_metadata.total_docs > 0 do
        analysis.total_size_bytes / analysis.index_metadata.total_docs
      else
        0.0
      end

    deletion_ratio =
      if analysis.index_metadata.total_docs > 0 do
        analysis.index_metadata.deleted_docs / analysis.index_metadata.total_docs
      else
        0.0
      end

    # Average compression ratio across segments
    avg_compression =
      if analysis.segment_count > 0 do
        analysis.segments
        |> Enum.map(& &1.compression_ratio)
        |> Enum.sum()
        |> Kernel./(analysis.segment_count)
      else
        0.0
      end

    metrics = %{
      space_per_doc: space_per_doc,
      deletion_ratio: deletion_ratio,
      compression_ratio: avg_compression,
      segment_efficiency:
        if analysis.segment_count > 0 do
          analysis.total_size_bytes / analysis.segment_count
        else
          0.0
        end,
      largest_field_percentage:
        analysis.field_analysis
        |> Map.values()
        |> Enum.map(& &1.percentage_of_index)
        |> Enum.max(fn -> 0.0 end)
    }

    {:ok, metrics}
  end

  @doc """
  Format analysis results for human-readable output.

  ## Parameters

  - `analysis` - Space analysis results

  ## Returns

  - `{:ok, formatted_string}` - Human-readable analysis summary

  ## Examples

      {:ok, analysis} = TantivyEx.SpaceAnalysis.analyze_index(analyzer, index, "test")
      {:ok, summary} = TantivyEx.SpaceAnalysis.format_summary(analysis)
      IO.puts(summary)
  """
  @spec format_summary(space_analysis()) :: {:ok, String.t()}
  def format_summary(analysis) do
    size_mb = analysis.total_size_bytes / 1024 / 1024

    summary = ~s"""
    Index Space Analysis Summary
    ============================

    Total Size: #{:erlang.float_to_binary(size_mb, decimals: 2)} MB (#{analysis.total_size_bytes} bytes)
    Segments: #{analysis.segment_count}
    Total Documents: #{analysis.index_metadata.total_docs}
    Deleted Documents: #{analysis.index_metadata.deleted_docs}
    Fields: #{analysis.index_metadata.num_fields}

    Storage Breakdown:
    - Postings: #{:erlang.float_to_binary(analysis.storage_breakdown.postings / 1024 / 1024, decimals: 2)} MB
    - Term Dictionary: #{:erlang.float_to_binary(analysis.storage_breakdown.term_dictionary / 1024 / 1024, decimals: 2)} MB
    - Fast Fields: #{:erlang.float_to_binary(analysis.storage_breakdown.fast_fields / 1024 / 1024, decimals: 2)} MB
    - Stored Fields: #{:erlang.float_to_binary(analysis.storage_breakdown.stored_fields / 1024 / 1024, decimals: 2)} MB
    - Other: #{:erlang.float_to_binary(analysis.storage_breakdown.other / 1024 / 1024, decimals: 2)} MB

    Largest Fields by Size:
    #{analysis.field_analysis |> Map.values() |> Enum.sort_by(& &1.total_size_bytes, :desc) |> Enum.take(5) |> Enum.map(fn field -> "- #{field.field_name}: #{:erlang.float_to_binary(field.total_size_bytes / 1024 / 1024, decimals: 2)} MB (#{:erlang.float_to_binary(field.percentage_of_index, decimals: 1)}%)" end) |> Enum.join("\n")}
    """

    {:ok, summary}
  end
end
