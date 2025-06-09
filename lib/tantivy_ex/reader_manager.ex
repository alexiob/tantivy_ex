defmodule TantivyEx.ReaderManager do
  @moduledoc """
  Advanced index reader management and reload policies for TantivyEx.
  """

  alias TantivyEx.Native

  @type manager_resource() :: reference()

  @spec new() :: {:ok, manager_resource()} | {:error, term()}
  def new do
    case Native.reader_manager_new() do
      {:ok, resource} -> {:ok, resource}
      error -> {:error, error}
    end
  end

  @spec set_policy(manager_resource(), String.t(), String.t()) :: :ok | {:error, term()}
  def set_policy(manager_resource, policy_type, config) do
    case Native.reader_manager_set_policy(manager_resource, policy_type, config) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec add_index(manager_resource(), reference(), String.t()) :: :ok | {:error, term()}
  def add_index(manager_resource, index_resource, index_id) do
    case Native.reader_manager_add_index(manager_resource, index_resource, index_id) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec remove_index(manager_resource(), String.t()) :: :ok | {:error, term()}
  def remove_index(manager_resource, index_id) do
    case Native.reader_manager_remove_index(manager_resource, index_id) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec get_reader(manager_resource(), String.t()) :: {:ok, reference()} | {:error, term()}
  def get_reader(manager_resource, index_id) do
    case Native.reader_manager_get_reader(manager_resource, index_id) do
      {:ok, reader} -> {:ok, reader}
      error -> {:error, error}
    end
  end

  @spec reload_reader(manager_resource(), String.t()) :: :ok | {:error, term()}
  def reload_reader(manager_resource, index_id) do
    case Native.reader_manager_reload_reader(manager_resource, index_id, false) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec reload_reader(manager_resource(), String.t(), boolean()) :: :ok | {:error, term()}
  def reload_reader(manager_resource, index_id, force_reload) do
    case Native.reader_manager_reload_reader(manager_resource, index_id, force_reload) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec reload_all(manager_resource()) :: :ok | {:error, term()}
  def reload_all(manager_resource) do
    case Native.reader_manager_reload_all(manager_resource) do
      :ok -> :ok
      error -> {:error, error}
    end
  end

  @spec get_health(manager_resource()) :: {:ok, String.t()} | {:error, term()}
  def get_health(manager_resource) do
    case Native.reader_manager_get_health(manager_resource) do
      {:ok, health} -> {:ok, health}
      error -> {:error, error}
    end
  end

  @spec get_stats(manager_resource()) :: {:ok, String.t()} | {:error, term()}
  def get_stats(manager_resource) do
    case Native.reader_manager_get_stats(manager_resource) do
      {:ok, stats} -> {:ok, stats}
      error -> {:error, error}
    end
  end

  @spec shutdown(manager_resource()) :: :ok | {:error, term()}
  def shutdown(manager_resource) do
    case Native.reader_manager_shutdown(manager_resource) do
      :ok -> :ok
      error -> {:error, error}
    end
  end
end
