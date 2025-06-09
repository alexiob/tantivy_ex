defmodule TantivyEx.Distributed.Supervisor do
  @moduledoc """
  Top-level supervisor for the distributed search system.

  This supervisor manages the entire distributed search infrastructure
  using OTP principles for fault tolerance and scalability.
  """

  use Supervisor

  @doc """
  Start the distributed search supervisor.

  ## Options

  - `:name` - Name for the supervisor (default: __MODULE__)
  - `:coordinator_name` - Name for the coordinator GenServer
  - `:registry_name` - Name for the node registry
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    coordinator_name = Keyword.get(opts, :coordinator_name, TantivyEx.Distributed.Coordinator)
    registry_name = Keyword.get(opts, :registry_name, TantivyEx.Distributed.Registry)

    children = [
      # Registry for tracking search nodes
      {Registry, keys: :unique, name: registry_name},

      # Main coordinator GenServer
      {TantivyEx.Distributed.Coordinator, name: coordinator_name, registry: registry_name},

      # Dynamic supervisor for search nodes
      {DynamicSupervisor, name: TantivyEx.Distributed.NodeSupervisor, strategy: :one_for_one},

      # Task supervisor for concurrent operations
      {Task.Supervisor, name: TantivyEx.Distributed.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
