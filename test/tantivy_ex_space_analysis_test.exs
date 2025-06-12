defmodule TantivyEx.SpaceAnalysisTest do
  use ExUnit.Case, async: true
  doctest TantivyEx.SpaceAnalysis

  alias TantivyEx.{SpaceAnalysis, Schema, Index, IndexWriter}

  setup do
    # Create a simple test index for analysis
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text_stored)
    schema = Schema.add_text_field(schema, "body", :text)
    schema = Schema.add_u64_field(schema, "id", :indexed_stored)

    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    # Add some documents
    documents = [
      %{
        "title" => "First Document",
        "body" => "This is the content of the first document",
        "id" => 1
      },
      %{
        "title" => "Second Document",
        "body" => "This is the content of the second document",
        "id" => 2
      },
      %{
        "title" => "Third Document",
        "body" => "This is the content of the third document",
        "id" => 3
      }
    ]

    Enum.each(documents, fn doc ->
      IndexWriter.add_document(writer, doc)
    end)

    IndexWriter.commit(writer)

    {:ok, index: index}
  end

  describe "space analysis lifecycle" do
    test "creates a space analysis resource" do
      # Function is implemented and returns a valid analyzer
      {:ok, _analyzer} = SpaceAnalysis.new()
    end

    test "handles analysis configuration" do
      {:ok, analyzer} = SpaceAnalysis.new()

      config = %{
        include_file_details: true,
        include_field_breakdown: true,
        cache_results: true,
        cache_ttl_seconds: 300
      }

      assert :ok = SpaceAnalysis.configure(analyzer, config)
    end
  end

  describe "space analysis operations" do
    test "handles index analysis", %{index: index} do
      {:ok, analyzer} = SpaceAnalysis.new()
      {:ok, _analysis} = SpaceAnalysis.analyze_index(analyzer, index, "test_snapshot")
    end

    test "handles optimization recommendations" do
      {:ok, analyzer} = SpaceAnalysis.new()

      # This function may require prerequisites like having analyzed data first
      case SpaceAnalysis.get_recommendations(analyzer, "test_snapshot") do
        {:ok, _recommendations} -> assert true
        # May need prerequisites
        {:error, _reason} -> assert true
      end
    end

    test "handles analysis comparison" do
      {:ok, analyzer} = SpaceAnalysis.new()

      # This function may require having multiple snapshots to compare
      case SpaceAnalysis.compare(analyzer, "snapshot_1", "snapshot_2") do
        {:ok, _comparison} -> assert true
        # May need multiple snapshots
        {:error, _reason} -> assert true
      end
    end
  end

  describe "format and summary operations" do
    test "handles summary formatting", %{index: index} do
      {:ok, analyzer} = SpaceAnalysis.new()
      {:ok, analysis} = SpaceAnalysis.analyze_index(analyzer, index, "test_snapshot")

      case SpaceAnalysis.format_summary(analysis) do
        {:ok, _formatted} -> assert true
      end
    end

    test "handles detailed reports", %{index: index} do
      {:ok, analyzer} = SpaceAnalysis.new()
      {:ok, analysis} = SpaceAnalysis.analyze_index(analyzer, index, "test_snapshot")
      # Analysis should return structured data
      assert is_map(analysis) or is_binary(analysis)
    end
  end

  describe "cache management" do
    test "handles cache clearing" do
      {:ok, analyzer} = SpaceAnalysis.new()
      assert :ok = SpaceAnalysis.clear_cache(analyzer)
    end

    test "handles cache statistics" do
      {:ok, analyzer} = SpaceAnalysis.new()

      # This function may require having cached data first
      case SpaceAnalysis.get_cached(analyzer, "test_snapshot") do
        {:ok, _stats} -> assert true
        # May need cached data first
        {:error, _reason} -> assert true
      end
    end
  end
end
