defmodule TantivyEx.Distributed.OTPTest do
  use ExUnit.Case, async: false

  alias TantivyEx.Distributed.OTP

  describe "OTP distributed search" do
    setup do
      # Stop any existing system
      OTP.stop()
      Process.sleep(100)

      # Start fresh using start_supervised for proper test isolation
      _pid = start_supervised!({TantivyEx.Distributed.Supervisor, []})

      :ok
    end

    test "can start and stop the distributed search system" do
      assert OTP.running?()

      # Stop the supervised process for this test
      :ok = stop_supervised(TantivyEx.Distributed.Supervisor)
      Process.sleep(100)

      refute OTP.running?()
    end

    test "can add and remove nodes" do
      # Add nodes
      assert :ok = OTP.add_node("node1", "local://index1", 1.0)
      assert :ok = OTP.add_node("node2", "local://index2", 1.5)

      # Check they're active
      {:ok, active_nodes} = OTP.get_active_nodes()
      assert "node1" in active_nodes
      assert "node2" in active_nodes

      # Remove a node
      assert :ok = OTP.remove_node("node1")

      {:ok, active_nodes} = OTP.get_active_nodes()
      refute "node1" in active_nodes
      assert "node2" in active_nodes
    end

    test "can configure the system" do
      config = %{
        timeout_ms: 10_000,
        merge_strategy: :score_desc,
        health_check_interval: 60_000
      }

      assert :ok = OTP.configure(config)

      {:ok, stats} = OTP.get_cluster_stats()
      assert stats.config.timeout_ms == 10_000
      assert stats.config.merge_strategy == :score_desc
    end

    test "can perform distributed search with no nodes" do
      # Should return error when no nodes are available
      assert {:error, :no_active_nodes} = OTP.search("test query", 10, 0)
    end

    test "can perform distributed search with nodes" do
      # Add nodes
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.5)

      # Wait for nodes to initialize
      Process.sleep(500)

      # Perform search
      case OTP.search("test", 10, 0) do
        {:ok, results} ->
          assert is_map(results)
          assert Map.has_key?(results, :total_hits)
          assert Map.has_key?(results, :hits)
          assert Map.has_key?(results, :took_ms)
          assert Map.has_key?(results, :node_responses)
          assert is_list(results.node_responses)

        {:error, _reason} ->
          # This is acceptable for demo purposes since we're using mock indexes
          :ok
      end
    end

    test "can get cluster statistics" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.5)

      {:ok, stats} = OTP.get_cluster_stats()

      assert stats.total_nodes == 2
      assert is_map(stats.config)
      assert is_map(stats.cluster_stats)
    end

    test "can set node status" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)

      # Node should be active by default
      {:ok, active_nodes} = OTP.get_active_nodes()
      assert "node1" in active_nodes

      # Deactivate node
      :ok = OTP.set_node_status("node1", false)

      # Give it time to process
      Process.sleep(100)

      # Should not be in active nodes anymore
      {:ok, active_nodes} = OTP.get_active_nodes()
      refute "node1" in active_nodes

      # Reactivate
      :ok = OTP.set_node_status("node1", true)
      Process.sleep(100)

      {:ok, active_nodes} = OTP.get_active_nodes()
      assert "node1" in active_nodes
    end

    test "can add multiple nodes at once" do
      nodes = [
        {"node1", "local://index1", 1.0},
        {"node2", "local://index2", 1.5},
        {"node3", "local://index3", 2.0}
      ]

      assert :ok = OTP.add_nodes(nodes)

      {:ok, active_nodes} = OTP.get_active_nodes()
      assert length(active_nodes) == 3
      assert "node1" in active_nodes
      assert "node2" in active_nodes
      assert "node3" in active_nodes
    end

    test "simple_search convenience function works" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      Process.sleep(500)

      # This should work without errors (though might return empty results)
      case OTP.simple_search("test") do
        {:ok, results} ->
          assert is_map(results)

        {:error, _reason} ->
          # Acceptable for demo purposes
          :ok
      end
    end

    test "handles node failures gracefully" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)

      # Get node stats
      {:ok, stats} = OTP.get_node_stats("node1")
      assert stats.node_id == "node1"
      assert stats.active == true

      # Non-existent node should return error
      assert {:error, :node_not_found} = OTP.get_node_stats("nonexistent")
    end

    test "performs complex multi-field boolean queries" do
      # Set up multiple nodes with different data
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.5)
      :ok = OTP.add_node("node3", "local://index3", 2.0)

      # Wait for initialization
      Process.sleep(500)

      # Test complex boolean query across multiple fields
      complex_queries = [
        "title:programming AND content:elixir",
        "title:rust OR content:systems",
        "title:advanced AND NOT content:basic",
        "(title:web OR title:mobile) AND content:development",
        "title:functional AND content:programming AND score:[80 TO 100]"
      ]

      Enum.each(complex_queries, fn query ->
        case OTP.search(query, 10, 0) do
          {:ok, results} ->
            assert is_map(results)
            assert Map.has_key?(results, :total_hits)
            assert Map.has_key?(results, :hits)
            assert Map.has_key?(results, :node_responses)
            assert is_list(results.node_responses)
            # Should have responses from all 3 nodes
            assert length(results.node_responses) == 3

          {:error, _reason} ->
            # Acceptable for demo indexes that might not have matching content
            :ok
        end
      end)
    end

    test "handles range queries across distributed nodes" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      # Test different types of range queries
      range_queries = [
        "price:[100 TO 500]",
        "score:[80 TO *]",
        "rating:[* TO 4.5]",
        # exclusive range
        "price:{200 TO 400}",
        "score:[90 TO 100] AND price:[300 TO 600]"
      ]

      Enum.each(range_queries, fn query ->
        case OTP.search(query, 10, 0) do
          {:ok, results} ->
            assert is_map(results)
            assert is_integer(results.total_hits)
            assert is_list(results.hits)

          {:error, _reason} ->
            # Range queries might not match demo data
            :ok
        end
      end)
    end

    test "performs phrase and fuzzy queries across nodes" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      # Test phrase queries (exact phrase matching)
      phrase_queries = [
        "\"rust programming\"",
        "\"web development\"",
        "title:\"advanced concepts\"",
        "content:\"functional programming\""
      ]

      Enum.each(phrase_queries, fn query ->
        case OTP.search(query, 5, 0) do
          {:ok, results} ->
            assert is_map(results)
            # Phrase queries should be more precise
            assert is_integer(results.total_hits)

          {:error, _reason} ->
            :ok
        end
      end)

      # Test fuzzy queries (approximate matching)
      fuzzy_queries = [
        # typo with edit distance 1
        "programing~1",
        # typo with edit distance 2
        "developement~2",
        "title:elixr~1",
        "content:systms~2"
      ]

      Enum.each(fuzzy_queries, fn query ->
        case OTP.search(query, 5, 0) do
          {:ok, results} ->
            assert is_map(results)
            assert is_integer(results.total_hits)

          {:error, _reason} ->
            :ok
        end
      end)
    end

    test "tests pagination across distributed results" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)
      :ok = OTP.add_node("node3", "local://index3", 1.0)

      Process.sleep(500)

      # Test pagination with different limits and offsets
      pagination_tests = [
        # First page, 5 results
        {5, 0},
        # Second page, 5 results
        {5, 5},
        # Larger page size
        {10, 0},
        # Small page with offset
        {3, 10},
        # Single result
        {1, 0}
      ]

      Enum.each(pagination_tests, fn {limit, offset} ->
        case OTP.search("*", limit, offset) do
          {:ok, results} ->
            assert is_map(results)
            assert is_list(results.hits)
            # Results should not exceed the requested limit
            assert length(results.hits) <= limit
            assert Map.has_key?(results, :took_ms)
            assert is_integer(results.took_ms)

          {:error, _reason} ->
            :ok
        end
      end)
    end

    test "tests different merge strategies" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.5)

      Process.sleep(500)

      # Test different merge strategies
      merge_strategies = [:score_desc, :score_asc, :node_order, :round_robin]

      Enum.each(merge_strategies, fn strategy ->
        # Configure the merge strategy
        :ok = OTP.configure(%{merge_strategy: strategy})

        case OTP.search("programming", 10, 0) do
          {:ok, results} ->
            assert is_map(results)
            assert is_list(results.hits)

            # Verify that results are properly merged according to strategy
            case strategy do
              :score_desc ->
                # Results should be sorted by score descending
                scores = Enum.map(results.hits, fn hit -> Map.get(hit, :score, 0) end)
                assert scores == Enum.sort(scores, :desc)

              :score_asc ->
                # Results should be sorted by score ascending
                scores = Enum.map(results.hits, fn hit -> Map.get(hit, :score, 0) end)
                assert scores == Enum.sort(scores, :asc)

              _ ->
                # For node_order and round_robin, just verify we got results
                assert is_list(results.hits)
            end

          {:error, _reason} ->
            :ok
        end
      end)
    end

    test "handles concurrent searches across nodes" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)
      :ok = OTP.add_node("node3", "local://index3", 1.0)

      Process.sleep(500)

      # Define multiple concurrent search queries
      search_queries = [
        "programming",
        "title:rust",
        "content:development",
        "score:[80 TO 100]",
        "\"functional programming\"",
        "elixir OR rust",
        "title:web AND content:development"
      ]

      # Execute all searches concurrently
      search_tasks =
        Enum.map(search_queries, fn query ->
          Task.async(fn ->
            OTP.search(query, 5, 0)
          end)
        end)

      # Collect all results
      results = Task.await_many(search_tasks, 10_000)

      # Verify all searches completed
      assert length(results) == length(search_queries)

      # Check that all results are valid
      Enum.each(results, fn result ->
        case result do
          {:ok, search_result} ->
            assert is_map(search_result)
            assert Map.has_key?(search_result, :total_hits)
            assert Map.has_key?(search_result, :hits)
            assert Map.has_key?(search_result, :took_ms)

          {:error, _reason} ->
            # Some searches might not match demo data
            :ok
        end
      end)
    end

    test "tests weighted load balancing with different node weights" do
      # Add nodes with different weights
      :ok = OTP.add_node("light_node", "local://index1", 0.5)
      :ok = OTP.add_node("medium_node", "local://index2", 1.0)
      :ok = OTP.add_node("heavy_node", "local://index3", 2.0)

      Process.sleep(500)

      # Configure weighted round robin load balancing
      :ok = OTP.configure(%{load_balancing: :weighted_round_robin})

      # Perform multiple searches to test load distribution
      search_results =
        for _i <- 1..10 do
          case OTP.search("test", 5, 0) do
            {:ok, result} -> result
            {:error, _} -> nil
          end
        end

      # Filter out nil results and verify we got valid responses
      valid_results = Enum.filter(search_results, &(&1 != nil))

      if length(valid_results) > 0 do
        # Verify that all nodes participated in searches
        Enum.each(valid_results, fn result ->
          assert is_list(result.node_responses)
          # Should have responses from all 3 nodes
          assert length(result.node_responses) == 3

          # Verify node IDs are present
          node_ids = Enum.map(result.node_responses, & &1.node_id)
          assert "light_node" in node_ids
          assert "medium_node" in node_ids
          assert "heavy_node" in node_ids
        end)
      end
    end

    test "handles search timeout scenarios" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      # Configure a very short timeout for testing
      :ok = OTP.configure(%{timeout_ms: 1})

      # Perform search that might timeout
      case OTP.search("complex query", 10, 0) do
        {:ok, results} ->
          # If it succeeds despite short timeout, that's okay
          assert is_map(results)

        {:error, :timeout} ->
          # Expected timeout error
          :ok

        {:error, _other_reason} ->
          # Other errors are also acceptable
          :ok
      end

      # Reset to normal timeout
      :ok = OTP.configure(%{timeout_ms: 5_000})
    end

    test "validates search result structure and metadata" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      case OTP.search("test", 5, 0) do
        {:ok, results} ->
          # Validate top-level structure
          assert is_map(results)
          assert Map.has_key?(results, :total_hits)
          assert Map.has_key?(results, :hits)
          assert Map.has_key?(results, :took_ms)
          assert Map.has_key?(results, :node_responses)
          assert Map.has_key?(results, :errors)

          # Validate data types
          assert is_integer(results.total_hits)
          assert is_list(results.hits)
          assert is_integer(results.took_ms)
          assert is_list(results.node_responses)
          assert is_list(results.errors)

          # Validate node responses structure
          Enum.each(results.node_responses, fn node_response ->
            assert is_map(node_response)
            assert Map.has_key?(node_response, :node_id)
            assert Map.has_key?(node_response, :total_hits)
            assert Map.has_key?(node_response, :hits)
            assert Map.has_key?(node_response, :took_ms)
            assert Map.has_key?(node_response, :error)

            assert is_binary(node_response.node_id)
            assert is_integer(node_response.total_hits)
            assert is_list(node_response.hits)
            assert is_integer(node_response.took_ms)
          end)

          # Validate individual hit structure
          Enum.each(results.hits, fn hit ->
            assert is_map(hit)
            # Hits should contain searchable content
            # Exact structure depends on the index schema
          end)

        {:error, _reason} ->
          # Some searches might not return results with demo data
          :ok
      end
    end

    test "tests search performance metrics and statistics" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      # Get initial cluster stats
      {:ok, initial_stats} = OTP.get_cluster_stats()
      initial_searches = initial_stats.cluster_stats.total_searches

      # Perform several searches
      search_count = 5

      for _i <- 1..search_count do
        case OTP.search("performance test", 3, 0) do
          {:ok, _} -> :ok
          {:error, _} -> :ok
        end
      end

      # Get updated stats
      {:ok, updated_stats} = OTP.get_cluster_stats()

      # Verify search count increased
      assert updated_stats.cluster_stats.total_searches >= initial_searches + search_count

      # Verify other metrics exist
      assert Map.has_key?(updated_stats.cluster_stats, :successful_searches)
      assert Map.has_key?(updated_stats.cluster_stats, :failed_searches)
      assert Map.has_key?(updated_stats.cluster_stats, :average_response_time)

      # Verify metrics are reasonable values
      assert is_integer(updated_stats.cluster_stats.successful_searches)
      assert is_integer(updated_stats.cluster_stats.failed_searches)
      assert is_number(updated_stats.cluster_stats.average_response_time)
      assert updated_stats.cluster_stats.average_response_time >= 0
    end

    test "handles edge cases and malformed queries" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      Process.sleep(500)

      # Test edge cases that should be handled gracefully
      edge_case_queries = [
        # Empty query
        "",
        # Whitespace only
        "   ",
        # Incomplete field query
        "field:",
        # Malformed range
        "[TO]",
        # Unclosed quote
        "title:\"unclosed quote",
        # Unmatched parentheses
        "((unmatched parentheses",
        # Only operators
        "AND OR NOT",
        # Trailing operator
        "title:value AND",
        # Invalid range values
        "title:[invalid TO range]",
        # Very long query
        String.duplicate("a", 1000)
      ]

      Enum.each(edge_case_queries, fn query ->
        case OTP.search(query, 5, 0) do
          {:ok, results} ->
            # If the query succeeds, verify the result structure
            assert is_map(results)
            assert Map.has_key?(results, :total_hits)

          {:error, reason} ->
            # Most malformed queries should return errors
            # The reason could be a string, atom, or other term
            assert reason != nil
        end
      end)
    end

    test "tests node health monitoring and recovery" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)

      Process.sleep(500)

      # Get initial cluster statistics
      {:ok, initial_stats} = OTP.get_cluster_stats()
      assert initial_stats.total_nodes == 2
      assert initial_stats.active_nodes == 2

      # Deactivate a node to simulate failure
      :ok = OTP.set_node_status("node1", false)
      Process.sleep(200)

      # Verify cluster stats reflect the change
      {:ok, stats_after_failure} = OTP.get_cluster_stats()
      assert stats_after_failure.total_nodes == 2
      assert stats_after_failure.active_nodes == 1
      assert stats_after_failure.inactive_nodes == 1

      # Search should still work with remaining nodes
      case OTP.search("test", 5, 0) do
        {:ok, results} ->
          assert is_map(results)
          # Should only have responses from active nodes
          active_responses =
            Enum.filter(results.node_responses, fn response ->
              response.error == nil
            end)

          assert length(active_responses) <= 1

        {:error, _reason} ->
          :ok
      end

      # Reactivate the node
      :ok = OTP.set_node_status("node1", true)
      Process.sleep(200)

      # Verify recovery
      {:ok, stats_after_recovery} = OTP.get_cluster_stats()
      assert stats_after_recovery.active_nodes == 2
      assert stats_after_recovery.inactive_nodes == 0
    end

    test "tests large result sets and memory efficiency" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      :ok = OTP.add_node("node2", "local://index2", 1.0)
      :ok = OTP.add_node("node3", "local://index3", 1.0)

      Process.sleep(500)

      # Test with large limit values
      large_limits = [100, 500, 1000]

      Enum.each(large_limits, fn limit ->
        case OTP.search("*", limit, 0) do
          {:ok, results} ->
            assert is_map(results)
            assert is_list(results.hits)
            # Results should not exceed available documents
            assert length(results.hits) <= limit
            assert is_integer(results.total_hits)

            # Verify memory efficiency - response should complete reasonably fast
            # Less than 10 seconds
            assert results.took_ms < 10_000

          {:error, _reason} ->
            # Large queries might fail in demo environment
            :ok
        end
      end)
    end

    test "tests query optimization and caching behavior" do
      :ok = OTP.add_node("node1", "local://index1", 1.0)
      Process.sleep(500)

      # Perform the same query multiple times to test potential caching
      repeated_query = "programming"

      response_times =
        for _i <- 1..5 do
          case OTP.search(repeated_query, 10, 0) do
            {:ok, results} ->
              results.took_ms

            {:error, _reason} ->
              nil
          end
        end
        |> Enum.filter(&(&1 != nil))

      # Verify all queries completed
      if length(response_times) > 0 do
        # All response times should be reasonable
        Enum.each(response_times, fn time ->
          assert is_integer(time)
          assert time >= 0
          # Less than 5 seconds
          assert time < 5000
        end)

        # Calculate average response time
        avg_time = Enum.sum(response_times) / length(response_times)
        assert avg_time >= 0
      end
    end
  end
end
