defmodule TantivyEx.MergePolicy do
  @moduledoc """
  Merge policy configuration for TantivyEx indexes.

  Merge policies control when and how index segments are merged together.
  This is important for index performance and storage efficiency.

  ## Available Policies

  - `LogMergePolicy` - Default policy that merges segments of similar sizes
  - `NoMergePolicy` - Never merges segments automatically

  ## Examples

      # Create a default log merge policy
      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy()

      # Create a custom log merge policy
      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy(%{
        min_num_segments: 4,
        max_docs_before_merge: 5_000_000,
        min_layer_size: 5_000,
        level_log_size: 0.8,
        del_docs_ratio_before_merge: 0.3
      })

      # Create a no-merge policy for testing
      {:ok, policy} = TantivyEx.MergePolicy.no_merge_policy()

      # Apply policy to an index writer
      TantivyEx.MergePolicy.set_merge_policy(index_writer, policy)
  """

  alias TantivyEx.Native

  @type merge_policy :: reference()

  @type log_merge_options :: %{
          optional(:min_num_segments) => non_neg_integer(),
          optional(:max_docs_before_merge) => non_neg_integer(),
          optional(:min_layer_size) => non_neg_integer(),
          optional(:level_log_size) => float(),
          optional(:del_docs_ratio_before_merge) => float()
        }

  @doc """
  Creates a new LogMergePolicy with default settings.

  LogMergePolicy groups segments into levels based on their size and merges
  segments within each level when there are enough segments or when the
  delete ratio exceeds the threshold.

  ## Returns

  - `{:ok, policy}` - The merge policy reference
  - `{:error, reason}` - If creation fails

  ## Examples

      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy()
  """
  @spec log_merge_policy() :: {:ok, merge_policy()} | {:error, term()}
  def log_merge_policy do
    case Native.log_merge_policy_new() do
      {:ok, policy} -> {:ok, policy}
      error -> error
    end
  end

  @doc """
  Creates a new LogMergePolicy with custom settings.

  ## Options

  - `:min_num_segments` - Minimum number of segments to merge (default: 8)
  - `:max_docs_before_merge` - Maximum docs in segment before it's excluded from merging (default: 10,000,000)
  - `:min_layer_size` - Minimum segment size for level grouping (default: 10,000)
  - `:level_log_size` - Log ratio between consecutive levels (default: 0.75)
  - `:del_docs_ratio_before_merge` - Delete ratio threshold to trigger merge (default: 1.0)

  ## Returns

  - `{:ok, policy}` - The merge policy reference
  - `{:error, reason}` - If creation fails or parameters are invalid

  ## Examples

      # More aggressive merging
      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy(%{
        min_num_segments: 4,
        del_docs_ratio_before_merge: 0.2
      })

      # Less aggressive merging for better write performance
      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy(%{
        min_num_segments: 12,
        max_docs_before_merge: 50_000_000
      })
  """
  @spec log_merge_policy(log_merge_options()) :: {:ok, merge_policy()} | {:error, term()}
  def log_merge_policy(options) when is_map(options) do
    min_num_segments = Map.get(options, :min_num_segments, 8)
    max_docs_before_merge = Map.get(options, :max_docs_before_merge, 10_000_000)
    min_layer_size = Map.get(options, :min_layer_size, 10_000)
    level_log_size = Map.get(options, :level_log_size, 0.75)
    del_docs_ratio_before_merge = Map.get(options, :del_docs_ratio_before_merge, 1.0)

    # Validate parameters
    cond do
      not is_integer(min_num_segments) or min_num_segments < 1 ->
        {:error, "min_num_segments must be a positive integer"}

      not is_integer(max_docs_before_merge) or max_docs_before_merge < 1 ->
        {:error, "max_docs_before_merge must be a positive integer"}

      not is_integer(min_layer_size) or min_layer_size < 0 ->
        {:error, "min_layer_size must be a non-negative integer"}

      not is_float(level_log_size) and not is_integer(level_log_size) ->
        {:error, "level_log_size must be a number"}

      not is_float(del_docs_ratio_before_merge) and not is_integer(del_docs_ratio_before_merge) ->
        {:error, "del_docs_ratio_before_merge must be a number"}

      del_docs_ratio_before_merge <= 0.0 or del_docs_ratio_before_merge > 1.0 ->
        {:error, "del_docs_ratio_before_merge must be between 0.0 and 1.0 (exclusive of 0.0)"}

      true ->
        case Native.log_merge_policy_with_options(
               min_num_segments,
               max_docs_before_merge,
               min_layer_size,
               # Ensure float
               level_log_size / 1.0,
               # Ensure float
               del_docs_ratio_before_merge / 1.0
             ) do
          {:ok, policy} -> {:ok, policy}
          error -> error
        end
    end
  end

  @doc """
  Creates a NoMergePolicy that never automatically merges segments.

  This is useful for testing scenarios or when you want complete manual
  control over segment merging.

  ## Returns

  - `{:ok, policy}` - The merge policy reference
  - `{:error, reason}` - If creation fails

  ## Examples

      {:ok, policy} = TantivyEx.MergePolicy.no_merge_policy()
  """
  @spec no_merge_policy() :: {:ok, merge_policy()} | {:error, term()}
  def no_merge_policy do
    case Native.no_merge_policy_new() do
      {:ok, policy} -> {:ok, policy}
      error -> error
    end
  end

  @doc """
  Sets the merge policy for an IndexWriter.

  ## Parameters

  - `index_writer` - The IndexWriter reference
  - `merge_policy` - The merge policy to set

  ## Returns

  - `:ok` - If the policy was set successfully
  - `{:error, reason}` - If setting the policy fails

  ## Examples

      {:ok, policy} = TantivyEx.MergePolicy.log_merge_policy()
      :ok = TantivyEx.MergePolicy.set_merge_policy(index_writer, policy)
  """
  @spec set_merge_policy(reference(), merge_policy()) :: :ok | {:error, term()}
  def set_merge_policy(index_writer, merge_policy) do
    case Native.index_writer_set_merge_policy(index_writer, merge_policy) do
      :ok -> :ok
      error -> error
    end
  end

  @doc """
  Gets information about the current merge policy of an IndexWriter.

  ## Parameters

  - `index_writer` - The IndexWriter reference

  ## Returns

  - `{:ok, info}` - Debug information about the current merge policy
  - `{:error, reason}` - If getting the info fails

  ## Examples

      {:ok, info} = TantivyEx.MergePolicy.get_merge_policy_info(index_writer)
      IO.puts(info)
  """
  @spec get_merge_policy_info(reference()) :: {:ok, String.t()} | {:error, term()}
  def get_merge_policy_info(index_writer) do
    case Native.index_writer_get_merge_policy_info(index_writer) do
      {:ok, info} -> {:ok, info}
      error -> error
    end
  end

  @doc """
  Manually triggers a merge operation for specific segments.

  This allows you to explicitly control which segments get merged,
  bypassing the merge policy's automatic decisions.

  ## Parameters

  - `index_writer` - The IndexWriter reference
  - `segment_ids` - List of segment ID strings to merge

  ## Returns

  - `:ok` - If the merge was triggered successfully
  - `{:error, reason}` - If the merge cannot be started

  ## Examples

      {:ok, segment_ids} = TantivyEx.Index.get_searchable_segment_ids(index)
      :ok = TantivyEx.MergePolicy.merge_segments(index_writer, segment_ids)
  """
  @spec merge_segments(reference(), [String.t()]) :: :ok | {:error, term()}
  def merge_segments(index_writer, segment_ids) when is_list(segment_ids) do
    case Native.index_writer_merge_segments(index_writer, segment_ids) do
      :ok -> :ok
      error -> error
    end
  end

  @doc """
  Waits for all merging threads to complete.

  This is useful when you want to ensure all pending merges are finished
  before proceeding, such as during testing or before closing an index.

  ## Parameters

  - `index_writer` - The IndexWriter reference

  ## Returns

  - `:ok` - If all merging threads completed successfully
  - `{:error, reason}` - If waiting fails

  ## Examples

      :ok = TantivyEx.MergePolicy.wait_merging_threads(index_writer)
  """
  @spec wait_merging_threads(reference()) :: :ok | {:error, term()}
  def wait_merging_threads(index_writer) do
    case Native.index_writer_wait_merging_threads(index_writer) do
      :ok -> :ok
      error -> error
    end
  end

  @doc """
  Gets the list of searchable segment IDs from an index.

  This is useful for understanding the current segment structure
  and for manual merge operations.

  ## Parameters

  - `index` - The Index reference

  ## Returns

  - `{:ok, segment_ids}` - List of segment ID strings
  - `{:error, reason}` - If getting segment IDs fails

  ## Examples

      {:ok, segment_ids} = TantivyEx.MergePolicy.get_searchable_segment_ids(index)
      IO.inspect(segment_ids, label: "Segment IDs")
  """
  @spec get_searchable_segment_ids(reference()) :: {:ok, [String.t()]} | {:error, term()}
  def get_searchable_segment_ids(index) do
    case Native.index_get_searchable_segment_ids(index) do
      {:ok, segment_ids} -> {:ok, segment_ids}
      error -> error
    end
  end

  @doc """
  Gets the number of searchable segments in an index.

  ## Parameters

  - `index` - The Index reference

  ## Returns

  - `{:ok, count}` - Number of segments
  - `{:error, reason}` - If getting the count fails

  ## Examples

      {:ok, segment_count} = TantivyEx.MergePolicy.get_num_segments(index)
      IO.puts("Index has \#{segment_count} segments")
  """
  @spec get_num_segments(reference()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_num_segments(index) do
    case Native.index_get_num_segments(index) do
      {:ok, count} -> {:ok, count}
      error -> error
    end
  end
end
