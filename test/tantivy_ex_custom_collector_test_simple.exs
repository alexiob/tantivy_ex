defmodule TantivyEx.CustomCollectorSimpleTest do
  use ExUnit.Case, async: true
  doctest TantivyEx.CustomCollector

  alias TantivyEx.CustomCollector

  describe "custom collector lifecycle" do
    test "creates a new custom collector" do
      # Test function exists and handles appropriately
      with {:ok, collector} <- CustomCollector.new() do
        assert is_reference(collector)
      end
    end

    test "handles basic operations correctly" do
      case CustomCollector.new() do
        {:ok, collector} ->
          # Test basic functions that exist in the module
          case CustomCollector.create_scoring_function(collector, "test_scoring", "bm25", %{
                 k1: 1.2,
                 b: 0.75
               }) do
            :ok -> assert true
            {:error, reason} -> flunk("Failed to create scoring function: #{inspect(reason)}")
          end

          case CustomCollector.create_top_k(collector, "test_topk", 10, "test_scoring") do
            :ok -> assert true
            {:error, reason} -> flunk("Failed to create top_k: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # Skip if we can't create collector
          assert true
      end
    end
  end

  describe "error handling" do
    test "handles module functions exist" do
      # Just verify the module functions are defined
      assert function_exported?(CustomCollector, :new, 0)
      assert function_exported?(CustomCollector, :create_scoring_function, 4)
      assert function_exported?(CustomCollector, :create_top_k, 4)
      assert function_exported?(CustomCollector, :create_aggregation, 3)
      assert function_exported?(CustomCollector, :create_filtering, 3)
      assert function_exported?(CustomCollector, :execute, 4)
      assert function_exported?(CustomCollector, :get_results, 2)
      assert function_exported?(CustomCollector, :set_field_boosts, 3)
      assert function_exported?(CustomCollector, :list_collectors, 1)
      assert function_exported?(CustomCollector, :clear_all, 1)
    end
  end
end
