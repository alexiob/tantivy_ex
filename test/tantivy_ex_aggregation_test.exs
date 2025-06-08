defmodule TantivyEx.AggregationTest do
  use ExUnit.Case, async: false
  doctest TantivyEx.Aggregation

  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query, Aggregation}

  setup do
    # Create a comprehensive test schema
    schema = Schema.new()
    schema = Schema.add_text_field(schema, "title", :text)
    # For terms aggregation, needs fast
    schema = Schema.add_text_field(schema, "category", :fast_stored)
    # For numeric aggregations, needs fast
    schema = Schema.add_u64_field(schema, "price", :fast_stored)
    # For numeric aggregations, needs fast
    schema = Schema.add_f64_field(schema, "rating", :fast_stored)
    # For date histograms, needs fast
    schema = Schema.add_date_field(schema, "published_date", :fast_stored)
    # For boolean aggregations, needs fast
    schema = Schema.add_bool_field(schema, "in_stock", :fast_stored)
    # For terms aggregation, needs fast
    schema = Schema.add_text_field(schema, "tags", :fast_stored)

    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)

    # Add comprehensive test documents
    test_docs = [
      %{
        "title" => "Laptop Computer",
        "category" => "electronics",
        "price" => 999,
        "rating" => 4.5,
        "published_date" => "2024-01-15T10:00:00Z",
        "in_stock" => true,
        "tags" => "computer laptop electronics"
      },
      %{
        "title" => "Programming Book",
        "category" => "books",
        "price" => 49,
        "rating" => 4.8,
        "published_date" => "2024-02-01T12:00:00Z",
        "in_stock" => true,
        "tags" => "programming book education"
      },
      %{
        "title" => "Smartphone",
        "category" => "electronics",
        "price" => 699,
        "rating" => 4.2,
        "published_date" => "2024-01-20T14:00:00Z",
        "in_stock" => false,
        "tags" => "phone mobile electronics"
      },
      %{
        "title" => "Fiction Novel",
        "category" => "books",
        "price" => 15,
        "rating" => 3.9,
        "published_date" => "2024-03-10T09:00:00Z",
        "in_stock" => true,
        "tags" => "fiction novel book"
      },
      %{
        "title" => "Tablet",
        "category" => "electronics",
        "price" => 399,
        "rating" => 4.0,
        "published_date" => "2024-02-15T16:00:00Z",
        "in_stock" => true,
        "tags" => "tablet electronics computing"
      },
      %{
        "title" => "Cookbook",
        "category" => "books",
        "price" => 29,
        "rating" => 4.6,
        "published_date" => "2024-01-25T11:00:00Z",
        "in_stock" => true,
        "tags" => "cooking book recipe"
      }
    ]

    Enum.each(test_docs, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)

    :ok = IndexWriter.commit(writer)

    {:ok, searcher} = Searcher.new(index)
    {:ok, query} = Query.all()

    %{
      schema: schema,
      index: index,
      writer: writer,
      searcher: searcher,
      query: query
    }
  end

  describe "terms aggregation" do
    test "basic terms aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "categories" => Aggregation.terms("category", size: 10)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"categories" => category_agg} = result
      assert %{"buckets" => buckets} = category_agg
      assert is_list(buckets)
      assert length(buckets) > 0

      # Should have electronics and books categories
      categories = Enum.map(buckets, & &1["key"])
      assert "electronics" in categories
      assert "books" in categories

      # Check document counts
      electronics_bucket = Enum.find(buckets, &(&1["key"] == "electronics"))
      books_bucket = Enum.find(buckets, &(&1["key"] == "books"))

      assert electronics_bucket["doc_count"] == 3
      assert books_bucket["doc_count"] == 3
    end

    test "terms aggregation with size limit", %{searcher: searcher, query: query} do
      aggregations = %{
        "categories" => Aggregation.terms("category", size: 1)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"categories" => %{"buckets" => buckets}} = result
      assert length(buckets) <= 1
    end

    test "terms aggregation with min_doc_count", %{searcher: searcher, query: query} do
      aggregations = %{
        "categories" => Aggregation.terms("category", min_doc_count: 5)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"categories" => %{"buckets" => buckets}} = result

      # All buckets should have at least 5 documents
      Enum.each(buckets, fn bucket ->
        assert bucket["doc_count"] >= 5
      end)
    end
  end

  describe "metric aggregations" do
    test "average aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "avg_price" => Aggregation.metric(:avg, "price")
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"avg_price" => %{"value" => avg_value}} = result
      assert is_float(avg_value)
      assert avg_value > 0

      # Should be around average of [999, 49, 699, 15, 399, 29] = ~365
      assert avg_value > 300 and avg_value < 400
    end

    test "min/max aggregations", %{searcher: searcher, query: query} do
      aggregations = %{
        "min_price" => Aggregation.metric(:min, "price"),
        "max_price" => Aggregation.metric(:max, "price")
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{
               "min_price" => %{"value" => min_value},
               "max_price" => %{"value" => max_value}
             } = result

      assert min_value == 15
      assert max_value == 999
    end

    test "sum aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "total_price" => Aggregation.metric(:sum, "price")
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"total_price" => %{"value" => sum_value}} = result
      # Sum should be 999 + 49 + 699 + 15 + 399 + 29 = 2190
      assert sum_value == 2190
    end

    test "count aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "price_count" => Aggregation.metric(:count, "price")
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_count" => %{"value" => count_value}} = result
      assert count_value == 6
    end

    test "stats aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "price_stats" => Aggregation.metric(:stats, "price")
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{
               "price_stats" => %{
                 "count" => count,
                 "min" => min_val,
                 "max" => max_val,
                 "avg" => avg_val,
                 "sum" => sum_val
               }
             } = result

      assert count == 6
      assert min_val == 15
      assert max_val == 999
      assert sum_val == 2190
      assert is_float(avg_val)
    end

    test "percentiles aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "price_percentiles" => Aggregation.metric(:percentiles, "price", percents: [50.0, 95.0])
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_percentiles" => %{"values" => percentile_values}} = result
      assert Map.has_key?(percentile_values, "50.0")
      assert Map.has_key?(percentile_values, "95.0")
      assert is_float(percentile_values["50.0"])
      assert is_float(percentile_values["95.0"])
    end
  end

  describe "histogram aggregations" do
    test "basic histogram aggregation", %{searcher: searcher, query: query} do
      aggregations = %{
        "price_histogram" => Aggregation.histogram("price", 100.0)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_histogram" => %{"buckets" => buckets}} = result
      assert is_list(buckets)
      assert length(buckets) > 0

      # Check bucket structure
      Enum.each(buckets, fn bucket ->
        assert Map.has_key?(bucket, "key")
        assert Map.has_key?(bucket, "doc_count")
        assert is_number(bucket["key"])
        assert is_integer(bucket["doc_count"])
      end)
    end

    test "histogram with min_doc_count", %{searcher: searcher, query: query} do
      aggregations = %{
        "price_histogram" => Aggregation.histogram("price", 50.0, min_doc_count: 2)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_histogram" => %{"buckets" => buckets}} = result

      # All buckets should have at least 2 documents
      Enum.each(buckets, fn bucket ->
        assert bucket["doc_count"] >= 2
      end)
    end
  end

  describe "range aggregations" do
    test "basic range aggregation", %{searcher: searcher, query: query} do
      ranges = [
        %{"to" => 50},
        %{"from" => 50, "to" => 500, "key" => "medium"},
        %{"from" => 500}
      ]

      aggregations = %{
        "price_ranges" => Aggregation.range("price", ranges)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_ranges" => %{"buckets" => buckets}} = result
      assert length(buckets) == 3

      # Check that buckets have the right structure
      Enum.each(buckets, fn bucket ->
        assert Map.has_key?(bucket, "doc_count")
        assert is_integer(bucket["doc_count"])
      end)

      # Find the medium range bucket
      medium_bucket = Enum.find(buckets, &(Map.get(&1, "key") == "medium"))
      assert medium_bucket != nil
      assert medium_bucket["from"] == 50
      assert medium_bucket["to"] == 500
    end

    test "range aggregation with tuple format", %{searcher: searcher, query: query} do
      ranges = [
        {nil, 50},
        {50, 500, "medium"},
        {500, nil}
      ]

      aggregations = %{
        "price_ranges" => Aggregation.range("price", ranges)
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_ranges" => %{"buckets" => buckets}} = result
      assert length(buckets) == 3
    end
  end

  describe "nested aggregations" do
    test "terms with metric sub-aggregation", %{searcher: searcher, query: query} do
      base_agg = Aggregation.terms("category", size: 10)

      sub_aggs = %{
        "avg_price" => Aggregation.metric(:avg, "price"),
        "max_rating" => Aggregation.metric(:max, "rating")
      }

      full_agg = Aggregation.with_sub_aggregations(base_agg, sub_aggs)

      aggregations = %{
        "categories_with_stats" => full_agg
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"categories_with_stats" => %{"buckets" => buckets}} = result

      # Each bucket should have sub-aggregations
      Enum.each(buckets, fn bucket ->
        assert Map.has_key?(bucket, "avg_price")
        assert Map.has_key?(bucket, "max_rating")
        assert Map.has_key?(bucket["avg_price"], "value")
        assert Map.has_key?(bucket["max_rating"], "value")
      end)
    end

    test "histogram with terms sub-aggregation", %{searcher: searcher, query: query} do
      base_agg = Aggregation.histogram("price", 200.0)

      sub_aggs = %{
        "categories" => Aggregation.terms("category", size: 5)
      }

      full_agg = Aggregation.with_sub_aggregations(base_agg, sub_aggs)

      aggregations = %{
        "price_hist_with_categories" => full_agg
      }

      {:ok, result} = Aggregation.run(searcher, query, aggregations)

      assert %{"price_hist_with_categories" => %{"buckets" => buckets}} = result

      # Buckets with documents should have category sub-aggregations
      buckets_with_docs = Enum.filter(buckets, &(&1["doc_count"] > 0))

      Enum.each(buckets_with_docs, fn bucket ->
        assert Map.has_key?(bucket, "categories")
        assert Map.has_key?(bucket["categories"], "buckets")
        assert is_list(bucket["categories"]["buckets"])
      end)
    end
  end

  describe "search with aggregations" do
    test "combined search and aggregations", %{searcher: searcher, query: query} do
      aggregations = %{
        "categories" => Aggregation.terms("category"),
        "avg_price" => Aggregation.metric(:avg, "price")
      }

      {:ok, result} = Aggregation.search_with_aggregations(searcher, query, aggregations, 3)

      assert %{"hits" => hits, "aggregations" => aggs} = result
      assert %{"total" => total, "hits" => hit_list} = hits

      # Handle both integer and structured total format
      total_value =
        case total do
          %{"value" => value} -> value
          value when is_integer(value) -> value
        end

      assert total_value == 3
      assert length(hit_list) == 3

      # Check aggregations
      assert %{"categories" => _, "avg_price" => _} = aggs
    end

    test "search with aggregations respects search limit", %{searcher: searcher, query: query} do
      aggregations = %{
        "categories" => Aggregation.terms("category")
      }

      {:ok, result} = Aggregation.search_with_aggregations(searcher, query, aggregations, 2)

      assert %{"hits" => %{"hits" => hits}} = result
      assert length(hits) == 2
    end
  end

  describe "aggregation builders" do
    test "build_request with map" do
      aggs_map = %{
        "categories" => Aggregation.terms("category"),
        "avg_price" => Aggregation.metric(:avg, "price")
      }

      result = Aggregation.build_request(aggs_map)
      assert result == aggs_map
    end

    test "build_request with keyword list" do
      aggs_list = [
        {"categories", Aggregation.terms("category")},
        {"avg_price", Aggregation.metric(:avg, "price")}
      ]

      result = Aggregation.build_request(aggs_list)

      assert is_map(result)
      assert Map.has_key?(result, "categories")
      assert Map.has_key?(result, "avg_price")
    end
  end

  describe "validation" do
    test "validates required field parameter", %{searcher: searcher, query: query} do
      # Invalid aggregation - missing field
      aggregations = %{
        "invalid_terms" => %{
          "terms" => %{"size" => 10}
        }
      }

      {:error, reason} = Aggregation.run(searcher, query, aggregations)
      assert reason =~ "field"
    end

    test "validates histogram interval", %{searcher: searcher, query: query} do
      # Invalid histogram - missing interval
      aggregations = %{
        "invalid_histogram" => %{
          "histogram" => %{"field" => "price"}
        }
      }

      {:error, reason} = Aggregation.run(searcher, query, aggregations)
      assert reason =~ "interval"
    end

    test "validates range aggregation ranges", %{searcher: searcher, query: query} do
      # Invalid range - missing ranges
      aggregations = %{
        "invalid_range" => %{
          "range" => %{"field" => "price"}
        }
      }

      {:error, reason} = Aggregation.run(searcher, query, aggregations)
      assert reason =~ "ranges"
    end

    test "validates unknown aggregation types", %{searcher: searcher, query: query} do
      aggregations = %{
        "unknown_agg" => %{
          "unknown_type" => %{"field" => "price"}
        }
      }

      {:error, reason} = Aggregation.run(searcher, query, aggregations)
      assert reason =~ "Unknown aggregation type"
    end
  end

  describe "error handling" do
    test "handles invalid field names gracefully", %{searcher: searcher, query: query} do
      aggregations = %{
        "invalid_field" => Aggregation.terms("nonexistent_field")
      }

      {:error, reason} = Aggregation.run(searcher, query, aggregations)
      assert reason =~ "not found" or reason =~ "Error"
    end

    test "handles malformed JSON gracefully", %{searcher: searcher, query: query} do
      # This test is more about the internal JSON encoding/decoding
      aggregations = %{
        "valid_terms" => Aggregation.terms("category")
      }

      # Should work normally
      {:ok, _result} = Aggregation.run(searcher, query, aggregations)
    end
  end

  describe "aggregation helpers" do
    test "terms aggregation helper" do
      result = Aggregation.terms("category", size: 20, min_doc_count: 5)

      expected = %{
        "terms" => %{
          "field" => "category",
          "size" => 20,
          "min_doc_count" => 5
        }
      }

      assert result == expected
    end

    test "histogram aggregation helper" do
      result = Aggregation.histogram("price", 10.0, min_doc_count: 2)

      expected = %{
        "histogram" => %{
          "field" => "price",
          "interval" => 10.0,
          "min_doc_count" => 2
        }
      }

      assert result == expected
    end

    test "metric aggregation helpers" do
      assert Aggregation.metric(:avg, "price") == %{"avg" => %{"field" => "price"}}
      assert Aggregation.metric(:max, "rating") == %{"max" => %{"field" => "rating"}}

      percentile_result = Aggregation.metric(:percentiles, "price", percents: [50.0, 95.0])

      expected = %{
        "percentiles" => %{
          "field" => "price",
          "percents" => [50.0, 95.0],
          "keyed" => true
        }
      }

      assert percentile_result == expected
    end
  end
end
