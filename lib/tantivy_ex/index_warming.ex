defmodule TantivyEx.IndexWarming do
  @moduledoc """
  Index warming and caching functionality for TantivyEx.
  """

  alias TantivyEx.Native

  @type warming_resource() :: reference()

  @spec new() :: {:ok, warming_resource()} | {:error, term()}
  def new do
    case Native.index_warming_new() do
      {:ok, resource} -> {:ok, resource}
      error -> {:error, error}
    end
  end

  @spec configure(
          warming_resource(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          String.t(),
          boolean()
        ) :: :ok | {:error, term()}
  def configure(
        warming_resource,
        cache_size_mb,
        ttl_seconds,
        strategy,
        eviction_policy,
        background_warming
      ) do
    case Native.index_warming_configure(
           warming_resource,
           cache_size_mb,
           ttl_seconds,
           strategy,
           eviction_policy,
           background_warming
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec add_preload_queries(warming_resource(), [String.t()]) :: :ok | {:error, term()}
  def add_preload_queries(warming_resource, queries) do
    queries_json = Jason.encode!(queries)

    case Native.index_warming_add_preload_queries(warming_resource, queries_json) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec warm_index(warming_resource(), reference(), String.t()) :: :ok | {:error, term()}
  def warm_index(warming_resource, index_resource, cache_key) do
    case Native.index_warming_warm_index(warming_resource, index_resource, cache_key) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec get_searcher(warming_resource(), String.t()) :: {:ok, reference()} | {:error, term()}
  def get_searcher(warming_resource, cache_key) do
    case Native.index_warming_get_searcher(warming_resource, cache_key) do
      {:ok, searcher} -> {:ok, searcher}
      error -> {:error, error}
    end
  end

  @spec evict_cache(warming_resource(), boolean()) :: :ok | {:error, term()}
  def evict_cache(warming_resource, force_all) do
    case Native.index_warming_evict_cache(warming_resource, force_all) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec get_stats(warming_resource()) :: {:ok, String.t()} | {:error, term()}
  def get_stats(warming_resource) do
    case Native.index_warming_get_stats(warming_resource) do
      json_string when is_binary(json_string) -> {:ok, json_string}
      error -> {:error, error}
    end
  end

  @spec clear_cache(warming_resource()) :: :ok | {:error, term()}
  def clear_cache(warming_resource) do
    case Native.index_warming_clear_cache(warming_resource) do
      :ok -> :ok
      error -> {:error, error}
    end
  end
end
