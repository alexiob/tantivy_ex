defmodule TantivyEx.DistributedTest do
  use ExUnit.Case, async: false

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher}
  alias TantivyEx.Distributed.OTP

  setup do
    # Create a simple test index for distributed operations
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "content", :text)
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)

    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    # Add some documents
    documents = [
      %{
        "title" => "Distributed Document 1",
        "content" => "This is content for distributed search",
        "id" => 1
      },
      %{
        "title" => "Distributed Document 2",
        "content" => "This is more content for distributed search",
        "id" => 2
      },
      %{
        "title" => "Distributed Document 3",
        "content" => "This is additional content for distributed search",
        "id" => 3
      }
    ]

    Enum.each(documents, fn doc ->
      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)

    {:ok, searcher} = Searcher.new(index)

    {:ok, index: index, searcher: searcher}
  end

  describe "OTP distributed search API" do
    test "OTP coordinator can be started and stopped" do
      assert {:ok, supervisor_pid} = OTP.start_link()
      assert Process.alive?(supervisor_pid)

      assert :ok = OTP.stop()
      refute OTP.running?()
    end

    test "OTP search nodes can be managed" do
      {:ok, _pid} = OTP.start_link()

      assert :ok = OTP.add_node("test_node", "test://localhost:8080", 1.0)

      assert {:ok, nodes} = OTP.get_active_nodes()
      assert Enum.member?(nodes, "test_node")

      assert :ok = OTP.remove_node("test_node")

      assert {:ok, nodes} = OTP.get_active_nodes()
      refute Enum.member?(nodes, "test_node")

      OTP.stop()
    end

    test "OTP health monitoring works" do
      {:ok, _pid} = OTP.start_link()

      assert {:ok, cluster_stats} = OTP.get_cluster_stats()
      assert is_map(cluster_stats)

      OTP.stop()
    end

    test "OTP configuration works" do
      {:ok, _pid} = OTP.start_link()

      config = %{
        timeout_ms: 5000,
        max_retries: 3,
        merge_strategy: :score_desc
      }

      assert :ok = OTP.configure(config)

      OTP.stop()
    end
  end
end
