defmodule TantivyEx.CustomCollector do
  @moduledoc """
  Custom collectors and scoring functionality for TantivyEx.
  """

  alias TantivyEx.Native

  @type collector_resource() :: reference()

  @spec new() :: {:ok, collector_resource()} | {:error, term()}
  def new() do
    case Native.custom_collector_new() do
      {:ok, resource} -> {:ok, resource}
      error -> {:error, error}
    end
  end

  @spec create_scoring_function(collector_resource(), String.t(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def create_scoring_function(collector_resource, name, scoring_type, parameters) do
    case Native.custom_collector_create_scoring_function(
           collector_resource,
           name,
           scoring_type,
           parameters
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec create_top_k(collector_resource(), String.t(), non_neg_integer(), String.t()) ::
          :ok | {:error, term()}
  def create_top_k(collector_resource, collector_name, k, scoring_function_name) do
    case Native.custom_collector_create_top_k(
           collector_resource,
           collector_name,
           k,
           scoring_function_name
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec create_aggregation(collector_resource(), String.t(), String.t()) :: :ok | {:error, term()}
  def create_aggregation(collector_resource, collector_name, aggregation_specs) do
    case Native.custom_collector_create_aggregation(
           collector_resource,
           collector_name,
           aggregation_specs
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec create_filtering(collector_resource(), String.t(), String.t()) :: :ok | {:error, term()}
  def create_filtering(collector_resource, collector_name, filter_specs) do
    case Native.custom_collector_create_filtering(
           collector_resource,
           collector_name,
           filter_specs
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec execute(collector_resource(), reference(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def execute(collector_resource, index_resource, collector_name, query_str) do
    case Native.custom_collector_execute(
           collector_resource,
           index_resource,
           collector_name,
           query_str
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec get_results(collector_resource(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_results(collector_resource, collector_name) do
    case Native.custom_collector_get_results(collector_resource, collector_name) do
      {:ok, results} -> {:ok, results}
      error -> {:error, error}
    end
  end

  @spec set_field_boosts(collector_resource(), String.t(), map()) :: :ok | {:error, term()}
  def set_field_boosts(collector_resource, scoring_function_name, field_boosts) do
    case Native.custom_collector_set_field_boosts(
           collector_resource,
           scoring_function_name,
           field_boosts
         ) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec list_collectors(collector_resource()) :: {:ok, list()} | {:error, term()}
  def list_collectors(collector_resource) do
    case Native.custom_collector_list_collectors(collector_resource) do
      {:ok, collectors} -> {:ok, collectors}
      error -> {:error, error}
    end
  end

  @spec clear_all(collector_resource()) :: :ok | {:error, term()}
  def clear_all(collector_resource) do
    case Native.custom_collector_clear_all(collector_resource) do
      :ok -> :ok
      error -> {:error, error}
    end
  end
end
