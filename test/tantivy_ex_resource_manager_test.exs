defmodule TantivyEx.ResourceManagerTest do
  use ExUnit.Case, async: false
  alias TantivyEx.ResourceManager

  setup do
    # Start the ResourceManager GenServer for testing
    {:ok, _pid} = ResourceManager.start_link([])
    :ok
  end

  describe "resource registration and tracking" do
    test "registers a resource successfully" do
      resource_id = "test_resource_1"
      resource_data = %{type: :index, path: "/tmp/test_index"}

      assert :ok = ResourceManager.register_resource(resource_id, resource_data)

      # Check if resource is tracked
      tracked_resources = ResourceManager.list_resources()
      assert Enum.any?(tracked_resources, &(&1.id == resource_id))
    end

    test "unregisters a resource" do
      resource_id = "test_resource_3"
      resource_data = %{type: :reader}

      :ok = ResourceManager.register_resource(resource_id, resource_data)
      assert :ok = ResourceManager.unregister_resource(resource_id)

      assert ResourceManager.get_resource(resource_id) == nil
    end
  end

  describe "error handling" do
    test "handles registration of duplicate resource IDs" do
      resource_id = "duplicate_test"
      resource_data = %{type: :index}

      assert :ok = ResourceManager.register_resource(resource_id, resource_data)

      # Attempting to register the same ID should return an error
      assert {:error, :already_exists} =
               ResourceManager.register_resource(resource_id, resource_data)
    end

    test "handles cleanup of non-existent resource" do
      assert {:error, :not_found} = ResourceManager.cleanup_resource("non_existent_resource")
    end
  end
end
