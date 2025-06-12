defmodule TantivyEx.ReaderManagerSimpleTest do
  use ExUnit.Case, async: true
  doctest TantivyEx.ReaderManager

  alias TantivyEx.ReaderManager

  describe "reader manager lifecycle" do
    test "creates a new reader manager" do
      # Function should work correctly and return a valid manager
      {:ok, manager} = ReaderManager.new()
      assert is_reference(manager)
    end

    test "handles basic operations correctly" do
      {:ok, manager} = ReaderManager.new()

      # Test basic functions that should work
      {:ok, _health} = ReaderManager.get_health(manager)
      {:ok, _stats} = ReaderManager.get_stats(manager)
    end
  end

  describe "error handling" do
    test "handles module functions exist" do
      # Just verify the module functions are defined
      assert function_exported?(ReaderManager, :new, 0)
      assert function_exported?(ReaderManager, :set_policy, 3)
      assert function_exported?(ReaderManager, :add_index, 3)
      assert function_exported?(ReaderManager, :remove_index, 2)
      assert function_exported?(ReaderManager, :get_reader, 2)
      assert function_exported?(ReaderManager, :reload_reader, 2)
      assert function_exported?(ReaderManager, :reload_reader, 3)
      assert function_exported?(ReaderManager, :reload_all, 1)
      assert function_exported?(ReaderManager, :get_health, 1)
      assert function_exported?(ReaderManager, :get_stats, 1)
      assert function_exported?(ReaderManager, :shutdown, 1)
    end
  end
end
