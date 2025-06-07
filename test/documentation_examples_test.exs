defmodule DocumentationExamplesTest do
  @moduledoc """
  Tests to validate that code examples in documentation actually work.

  This ensures our documentation stays accurate and examples remain functional.
  """

  use ExUnit.Case, async: true
  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Document}

  # Helper modules for testing documentation examples
  defmodule MyApp.SchemaValidator do
    def validate_schema(schema) do
      with fields when is_list(fields) <- Schema.get_field_names(schema),
           :ok <- check_required_fields(fields),
           :ok <- check_field_types(schema, fields) do
        {:ok, schema}
      else
        {:error, reason} -> {:error, "Schema validation failed: #{reason}"}
      end
    end

    defp check_required_fields(fields) do
      required = ["title", "content"]
      missing = required -- fields

      case missing do
        [] -> :ok
        missing_fields -> {:error, "Missing required fields: #{inspect(missing_fields)}"}
      end
    end

    defp check_field_types(schema, fields) do
      # Simple validation - just check that we can get field type
      Enum.reduce_while(fields, :ok, fn field, acc ->
        case Schema.get_field_type(schema, field) do
          {:ok, _type} -> {:cont, acc}
          {:error, reason} -> {:halt, {:error, "Invalid field #{field}: #{reason}"}}
        end
      end)
    end
  end

  defmodule MyApp.DocumentValidator do
    def validate_product(document) do
      with {:ok, doc} <- validate_required_fields(document),
           {:ok, doc} <- validate_price_range(doc),
           {:ok, doc} <- validate_category_format(doc) do
        {:ok, doc}
      end
    end

    defp validate_required_fields(doc) do
      required = ["title", "price", "category"]
      missing = required -- Map.keys(doc)

      case missing do
        [] -> {:ok, doc}
        fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
      end
    end

    defp validate_price_range(doc) do
      price = Map.get(doc, "price", 0)

      if price > 0 and price < 1_000_000 do
        {:ok, doc}
      else
        {:error, "Price must be between 1 and 999,999"}
      end
    end

    defp validate_category_format(doc) do
      category = Map.get(doc, "category", "")

      if String.starts_with?(category, "/") do
        {:ok, doc}
      else
        {:error, "Category must start with '/'"}
      end
    end
  end

  defmodule MyApp.SearchResult do
    defstruct [
      :score,
      :normalized_score,
      :doc_id,
      :title,
      :content,
      :author,
      :rating,
      :url,
      :metadata
    ]

    def from_tantivy_result(result, max_score \\ nil) do
      # Extract score and document from result map
      score = result["score"]
      document = Map.delete(result, "score") |> Map.delete("doc_id")

      %__MODULE__{
        score: score,
        normalized_score: normalize_score(score, max_score),
        title: document["title"],
        content: document["content"],
        author: document["author"],
        rating: document["rating"],
        url: build_url(document),
        metadata: extract_metadata(document)
      }
    end

    defp normalize_score(score, nil), do: score

    defp normalize_score(score, max_score) when max_score > 0 do
      Float.round(score / max_score * 100, 2)
    end

    defp normalize_score(_, _), do: 0.0

    defp build_url(%{"id" => id, "type" => "article"}), do: "/articles/#{id}"
    defp build_url(%{"id" => id, "type" => "product"}), do: "/products/#{id}"
    defp build_url(%{"id" => id}), do: "/documents/#{id}"
    defp build_url(_), do: nil

    defp extract_metadata(document) do
      document
      |> Map.take(["type", "rating", "id"])
      |> Map.reject(fn {_, v} -> is_nil(v) end)
    end
  end

  defmodule MyApp.ResultProcessor do
    def process_search_results(results) do
      max_score =
        results
        |> Enum.map(& &1["score"])
        |> Enum.max(fn -> 1.0 end)

      results
      |> Enum.map(&extract_result_data(&1, max_score))
      |> Enum.sort_by(& &1.normalized_score, :desc)
    end

    defp extract_result_data(result, max_score) do
      score = result["score"]

      %{
        score: score,
        normalized_score: Float.round(score / max_score * 100, 2),
        title: result["title"] || "Untitled",
        author: result["author"] || "Unknown",
        rating: result["rating"] || 0.0,
        url: generate_url(result["id"], result["type"])
      }
    end

    defp generate_url(doc_id, "article"), do: "/articles/#{doc_id}"
    defp generate_url(doc_id, "product"), do: "/products/#{doc_id}"
    defp generate_url(doc_id, _), do: "/documents/#{doc_id}"
  end

  defmodule TestArticleCreator do
    def create_article_document(article, author) do
      %{
        "title" => article.title,
        "content" => article.body,
        "author" => author.name,
        "author_id" => author.id,
        "published_at" => DateTime.to_iso8601(article.published_at),
        "word_count" => String.split(article.body) |> length(),
        "category" => "/articles/#{article.category}",
        "tags" => Enum.join(article.tags, " "),
        "featured" => article.featured?,
        "views" => article.view_count
      }
    end
  end

  describe "Document Guide Examples" do
    setup do
      # Basic schema from the documentation
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text)
        |> Schema.add_text_field("author", :text_stored)
        |> Schema.add_date_field("published_at", :indexed_stored)
        |> Schema.add_text_field("tags", :text_stored)
        |> Schema.add_f64_field("price", :fast_stored)
        |> Schema.add_bool_field("available", :indexed_stored)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      %{schema: schema, index: index, writer: writer}
    end

    test "basic document creation example from docs", %{writer: writer, schema: schema} do
      # Example from the documentation
      document = %{
        "title" => "Introduction to Elixir",
        "content" =>
          "Elixir is a dynamic, functional language designed for building maintainable applications.",
        "author" => "José Valim",
        "published_at" => "2011-07-11T00:00:00Z",
        "tags" => "/programming/functional/elixir",
        "price" => 49.99,
        "available" => true
      }

      # This should work according to the documentation
      assert {:ok, _result} = Document.add(writer, document, schema)
      assert :ok = IndexWriter.commit(writer)
    end

    test "blog post example from docs", %{writer: writer, schema: schema} do
      blog_post = %{
        "title" => "Getting Started with TantivyEx",
        "content" =>
          "TantivyEx brings powerful full-text search capabilities to Elixir applications...",
        "author" => "Your Name",
        "published_at" => "2024-01-15T10:30:00Z",
        "tags" => "/blog/tutorials/elixir"
      }

      assert {:ok, _result} = Document.add(writer, blog_post, schema)
    end

    test "batch document processing from docs", %{writer: writer, schema: schema} do
      documents = [
        %{
          "title" => "Document 1",
          "content" => "Content for first document",
          "author" => "Author 1",
          "published_at" => "2024-01-01T00:00:00Z",
          "price" => 29.99,
          "available" => true
        },
        %{
          "title" => "Document 2",
          "content" => "Content for second document",
          "author" => "Author 2",
          "published_at" => "2024-01-02T00:00:00Z",
          "price" => 39.99,
          "available" => false
        }
      ]

      options = %{batch_size: 10, validate: true}
      assert {:ok, _result} = Document.add_batch(writer, documents, schema, options)
    end

    test "document validation from docs", %{schema: schema} do
      doc = %{
        "title" => "Test",
        # String that should be converted to float
        "price" => "29.99",
        "published_at" => "2024-01-15T10:30:00Z"
      }

      assert {:ok, validated} = Document.validate(doc, schema)
      # Price should be converted to float
      assert is_float(validated["price"])
      assert validated["price"] == 29.99
    end
  end

  describe "Search Results Guide Examples" do
    setup do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text)
        |> Schema.add_f64_field("score", :fast_stored)
        |> Schema.add_text_field("category", :text_stored)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Add some test documents
      docs = [
        %{
          "title" => "Elixir Programming Guide",
          "content" => "A comprehensive guide to Elixir programming language",
          "score" => 95.5,
          "category" => "programming"
        },
        %{
          "title" => "Functional Programming Concepts",
          "content" => "Understanding functional programming with Elixir",
          "score" => 88.0,
          "category" => "programming"
        }
      ]

      Enum.each(docs, fn doc ->
        {:ok, _} = Document.add(writer, doc, schema)
      end)

      :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      %{schema: schema, index: index, searcher: searcher}
    end

    test "basic search result processing", %{searcher: searcher, index: index} do
      # Create a simple query parser and parse the query
      {:ok, parser} = TantivyEx.Query.parser(index, ["title", "content"])
      {:ok, query} = TantivyEx.Query.parse(parser, "Elixir")

      # Perform search
      {:ok, results} = Searcher.search(searcher, query, 10)

      # Results should be processable
      assert is_list(results)
      assert length(results) > 0

      # Each result should have the expected structure based on our search implementation
      [first_result | _] = results
      # Results are maps, not tuples
      assert is_map(first_result)
      assert Map.has_key?(first_result, "score")
      assert Map.has_key?(first_result, "doc_id")
      assert is_float(first_result["score"])
      assert is_integer(first_result["doc_id"])
    end
  end

  describe "README Examples" do
    test "quick start example from README" do
      # Example from README.md
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("body", :text)
        |> Schema.add_u64_field("id", :indexed_stored)
        |> Schema.add_date_field("published_at", :fast)

      # Create an index
      assert {:ok, index} = Index.create_in_ram(schema)

      # Get a writer
      assert {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Add documents
      doc = %{
        "title" => "Getting Started with TantivyEx",
        "body" => "This is a comprehensive guide to using TantivyEx...",
        "id" => 1,
        "published_at" => "2024-01-15T10:30:00Z"
      }

      assert {:ok, _} = Document.add(writer, doc, schema)
      assert :ok = IndexWriter.commit(writer)

      # Search
      assert {:ok, searcher} = Searcher.new(index)

      # We need to create a query first
      assert {:ok, parser} = TantivyEx.Query.parser(index, ["title", "body"])
      assert {:ok, query} = TantivyEx.Query.parse(parser, "comprehensive guide")
      assert {:ok, results} = Searcher.search(searcher, query, 10)
      assert is_list(results)
    end
  end

  describe "Field Type Examples" do
    test "all field types from documentation work" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_u64_field("count", :indexed_stored)
        |> Schema.add_i64_field("delta", :indexed_stored)
        |> Schema.add_f64_field("price", :fast_stored)
        |> Schema.add_bool_field("active", :indexed_stored)
        |> Schema.add_date_field("created_at", :indexed_stored)
        |> Schema.add_bytes_field("data", :stored)
        |> Schema.add_json_field("metadata", :stored)

      assert is_reference(schema)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      doc = %{
        "title" => "Test Document",
        "count" => 42,
        "delta" => -15,
        "price" => 99.99,
        "active" => true,
        "created_at" => "2024-01-15T10:30:00Z",
        # "Hello World" in base64
        "data" => "SGVsbG8gV29ybGQ=",
        "metadata" => %{"category" => "test", "priority" => 1}
      }

      assert {:ok, _} = Document.add(writer, doc, schema)
      assert :ok = IndexWriter.commit(writer)
    end
  end

  describe "Schema Design Examples" do
    test "schema validation from schema.md docs" do
      # Create a valid schema
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text)
        |> Schema.add_u64_field("timestamp", :indexed)

      # Should pass validation
      assert {:ok, _validated_schema} = MyApp.SchemaValidator.validate_schema(schema)

      # Create invalid schema (missing required fields)
      invalid_schema =
        Schema.new()
        |> Schema.add_text_field("description", :text)

      # Should fail validation
      assert {:error, error_msg} = MyApp.SchemaValidator.validate_schema(invalid_schema)
      assert String.contains?(error_msg, "Missing required fields")
    end

    test "custom tokenizer usage from schema.md docs" do
      # Text field with custom tokenizer
      schema =
        Schema.new()
        |> Schema.add_text_field_with_tokenizer("product_code", :text_stored, "whitespace")
        |> Schema.add_text_field_with_tokenizer("tags", :text, "whitespace")
        |> Schema.add_text_field("title", :text_stored)

      assert is_reference(schema)

      # Verify we can create an index with this schema
      assert {:ok, index} = Index.create_in_ram(schema)
      assert {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Test document with custom tokenized fields
      doc = %{
        "product_code" => "ABC-123-XYZ",
        "tags" => "electronics gadget bluetooth",
        "title" => "Bluetooth Headphones"
      }

      assert {:ok, _} = Document.add(writer, doc, schema)
      assert :ok = IndexWriter.commit(writer)
    end

    test "e-commerce schema from README.md" do
      # Product search schema from README
      schema =
        Schema.new()
        |> Schema.add_text_field("name", :text_stored)
        |> Schema.add_text_field("description", :text)
        |> Schema.add_f64_field("price", :fast_stored)
        |> Schema.add_facet_field("category")
        |> Schema.add_bool_field("in_stock", :indexed_stored)
        |> Schema.add_u64_field("product_id", :indexed_stored)

      assert is_reference(schema)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Test product document
      product = %{
        "name" => "Wireless Headphones",
        "description" => "High-quality wireless headphones with noise cancellation",
        "price" => 199.99,
        "category" => "/electronics/audio",
        "in_stock" => true,
        "product_id" => 12345
      }

      assert {:ok, _} = Document.add(writer, product, schema)
      assert :ok = IndexWriter.commit(writer)
    end

    test "blog schema from README.md" do
      # Blog post schema with custom tokenizers
      schema =
        Schema.new()
        |> Schema.add_text_field_with_tokenizer("title", :text_stored, "en_stem")
        |> Schema.add_text_field_with_tokenizer("content", :text, "en_stem")
        |> Schema.add_text_field("tags", :text_stored)
        |> Schema.add_date_field("published_at", :fast_stored)
        |> Schema.add_u64_field("author_id", :fast)

      assert is_reference(schema)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Test blog post document
      blog_post = %{
        "title" => "Understanding Functional Programming",
        "content" => "Functional programming emphasizes immutability and pure functions...",
        "tags" => "programming functional elixir",
        "published_at" => "2024-01-15T10:30:00Z",
        "author_id" => 1001
      }

      assert {:ok, _} = Document.add(writer, blog_post, schema)
      assert :ok = IndexWriter.commit(writer)
    end

    test "log analysis schema from README.md" do
      # Application log schema
      schema =
        Schema.new()
        |> Schema.add_text_field("message", :text_stored)
        |> Schema.add_text_field("level", :text)
        |> Schema.add_ip_addr_field("client_ip", :indexed_stored)
        |> Schema.add_date_field("timestamp", :fast_stored)
        |> Schema.add_json_field("metadata", :stored)

      assert is_reference(schema)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Test log entry document
      log_entry = %{
        "message" => "User login successful",
        "level" => "INFO",
        "client_ip" => "192.168.1.100",
        "timestamp" => "2024-01-15T10:30:00Z",
        "metadata" => %{"user_id" => 12345, "session_id" => "abc123"}
      }

      assert {:ok, _} = Document.add(writer, log_entry, schema)
      assert :ok = IndexWriter.commit(writer)
    end
  end

  describe "Advanced Search Examples" do
    setup do
      # Create a comprehensive schema for search testing
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text)
        |> Schema.add_text_field("author", :text_stored)
        |> Schema.add_f64_field("price", :indexed_stored)
        |> Schema.add_u64_field("timestamp", :indexed_stored)
        |> Schema.add_bool_field("featured", :indexed_stored)
        |> Schema.add_facet_field("category")

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Add test documents
      docs = [
        %{
          "title" => "Elixir Programming Guide",
          "content" => "Learn functional programming with Elixir",
          "author" => "José Valim",
          "price" => 49.99,
          "timestamp" => 1_640_995_200,
          "featured" => true,
          "category" => "/programming/functional"
        },
        %{
          "title" => "JavaScript Fundamentals",
          "content" => "Master JavaScript programming concepts",
          "author" => "John Doe",
          "price" => 29.99,
          "timestamp" => 1_640_995_300,
          "featured" => false,
          "category" => "/programming/web"
        },
        %{
          "title" => "Advanced Elixir Patterns",
          "content" => "Deep dive into advanced Elixir techniques",
          "author" => "Jane Smith",
          "price" => 79.99,
          "timestamp" => 1_640_995_400,
          "featured" => true,
          "category" => "/programming/functional"
        }
      ]

      Enum.each(docs, fn doc ->
        {:ok, _} = Document.add(writer, doc, schema)
      end)

      :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      %{schema: schema, index: index, searcher: searcher}
    end

    test "boolean queries from search.md docs", %{searcher: searcher, index: index} do
      # Test AND operator
      {:ok, parser} = TantivyEx.Query.parser(index, ["title", "content"])
      {:ok, query} = TantivyEx.Query.parse(parser, "elixir AND programming")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0

      # Test OR operator
      {:ok, query} = TantivyEx.Query.parse(parser, "elixir OR javascript")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0

      # Test NOT operator - should find programming content but not JavaScript
      {:ok, query} = TantivyEx.Query.parse(parser, "programming NOT javascript")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0
    end

    test "range queries from search.md docs", %{searcher: searcher, index: index} do
      # Test numeric range queries for price
      {:ok, parser} = TantivyEx.Query.parser(index, ["price"])
      {:ok, query} = TantivyEx.Query.parse(parser, "price:[30.0 TO 80.0]")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0

      # Test timestamp range queries
      {:ok, parser} = TantivyEx.Query.parser(index, ["timestamp"])
      {:ok, query} = TantivyEx.Query.parse(parser, "timestamp:[1640995200 TO 1640995400]")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0
    end

    test "facet queries from search.md docs", %{searcher: searcher, index: index} do
      # Test exact facet match
      {:ok, parser} = TantivyEx.Query.parser(index, ["category"])
      {:ok, query} = TantivyEx.Query.parse(parser, "category:\"/programming/functional\"")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0
    end

    test "field-specific search from search.md docs", %{searcher: searcher, index: index} do
      # Search only in title field
      {:ok, parser} = TantivyEx.Query.parser(index, ["title"])
      {:ok, query} = TantivyEx.Query.parse(parser, "title:Elixir")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0

      # Search in author field
      {:ok, parser} = TantivyEx.Query.parser(index, ["author"])
      {:ok, query} = TantivyEx.Query.parse(parser, "author:José")
      {:ok, results} = Searcher.search(searcher, query, 10)
      assert length(results) > 0
    end
  end

  describe "Dynamic Document Creation Examples" do
    test "dynamic document creation from documents.md" do
      # Mock article and author data
      article = %{
        title: "Understanding GenServers",
        body: "GenServers are the foundation of OTP applications in Elixir",
        category: "tutorials",
        tags: ["elixir", "otp", "genserver"],
        featured?: true,
        view_count: 1500,
        published_at: ~U[2024-01-15 10:30:00Z]
      }

      author = %{
        name: "Alice Developer",
        id: 123
      }

      # Test document creation
      document = TestArticleCreator.create_article_document(article, author)

      assert document["title"] == "Understanding GenServers"
      assert document["author"] == "Alice Developer"
      assert document["author_id"] == 123
      assert document["word_count"] == 9
      assert document["category"] == "/articles/tutorials"
      assert document["tags"] == "elixir otp genserver"
      assert document["featured"] == true
      assert document["views"] == 1500
      assert String.contains?(document["published_at"], "2024-01-15T10:30:00")
    end

    test "multiple language support from documents.md" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title_en", :text_stored)
        |> Schema.add_text_field("title_es", :text_stored)
        |> Schema.add_text_field("title_fr", :text_stored)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Multiple language document
      multilang_doc = %{
        "title_en" => "Hello World",
        "title_es" => "Hola Mundo",
        "title_fr" => "Bonjour le Monde"
      }

      assert {:ok, _} = Document.add(writer, multilang_doc, schema)
      assert :ok = IndexWriter.commit(writer)
    end
  end

  describe "Custom Validation Examples" do
    test "custom validation functions from documents.md" do
      # Test valid product
      valid_product = %{
        "title" => "Laptop Computer",
        "price" => 999.99,
        "category" => "/electronics/computers"
      }

      assert {:ok, _} = MyApp.DocumentValidator.validate_product(valid_product)

      # Test missing required fields
      invalid_product = %{
        "title" => "Laptop Computer"
      }

      assert {:error, error_msg} = MyApp.DocumentValidator.validate_product(invalid_product)
      assert String.contains?(error_msg, "Missing required fields")

      # Test invalid price range
      invalid_price_product = %{
        "title" => "Laptop Computer",
        "price" => 2_000_000,
        "category" => "/electronics/computers"
      }

      assert {:error, error_msg} = MyApp.DocumentValidator.validate_product(invalid_price_product)
      assert String.contains?(error_msg, "Price must be between")

      # Test invalid category format
      invalid_category_product = %{
        "title" => "Laptop Computer",
        "price" => 999.99,
        "category" => "electronics"
      }

      assert {:error, error_msg} =
               MyApp.DocumentValidator.validate_product(invalid_category_product)

      assert String.contains?(error_msg, "Category must start with")
    end

    test "type conversion validation from documents.md" do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_f64_field("price", :indexed_stored)
        |> Schema.add_bool_field("available", :indexed_stored)
        |> Schema.add_u64_field("count", :indexed_stored)

      # Test automatic type conversion
      document_with_strings = %{
        "title" => "Test Product",
        # String -> f64
        "price" => "29.99",
        # String -> boolean
        "available" => "true",
        # String -> u64
        "count" => "42"
      }

      assert {:ok, validated} = Document.validate(document_with_strings, schema)
      assert is_float(validated["price"])
      assert validated["price"] == 29.99
      assert is_boolean(validated["available"])
      assert validated["available"] == true
      assert is_integer(validated["count"])
      assert validated["count"] == 42
    end
  end

  describe "Enhanced Result Processing Examples" do
    setup do
      schema =
        Schema.new()
        |> Schema.add_text_field("title", :text_stored)
        |> Schema.add_text_field("content", :text)
        |> Schema.add_text_field("author", :text_stored)
        |> Schema.add_f64_field("rating", :indexed_stored)
        |> Schema.add_u64_field("id", :indexed_stored)
        |> Schema.add_text_field("type", :text_stored)

      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)

      # Add test documents with different types
      docs = [
        %{
          "title" => "Advanced Elixir Techniques",
          "content" => "Deep dive into OTP and concurrency patterns",
          "author" => "Expert Developer",
          "rating" => 4.8,
          "id" => 1,
          "type" => "article"
        },
        %{
          "title" => "Premium Laptop",
          "content" => "High-performance laptop for developers",
          "author" => "TechCorp",
          "rating" => 4.5,
          "id" => 2,
          "type" => "product"
        }
      ]

      Enum.each(docs, fn doc ->
        {:ok, _} = Document.add(writer, doc, schema)
      end)

      :ok = IndexWriter.commit(writer)
      {:ok, searcher} = Searcher.new(index)

      %{schema: schema, index: index, searcher: searcher}
    end

    test "enhanced result format from search_results.md docs", %{searcher: searcher, index: index} do
      # Perform search
      {:ok, parser} = TantivyEx.Query.parser(index, ["title", "content"])
      {:ok, query} = TantivyEx.Query.parse(parser, "elixir")
      {:ok, results} = Searcher.search(searcher, query, 10)

      # Process results with enhanced format
      enhanced_results =
        results
        |> Enum.map(&MyApp.SearchResult.from_tantivy_result(&1, 2.0))

      assert length(enhanced_results) > 0

      [first_result | _] = enhanced_results
      assert %MyApp.SearchResult{} = first_result
      assert is_float(first_result.score)
      assert is_binary(first_result.title)
      assert is_map(first_result.metadata)
      assert String.starts_with?(first_result.url, "/")
    end

    test "result processing with score normalization", %{searcher: searcher, index: index} do
      # Perform search and process results
      {:ok, parser} = TantivyEx.Query.parser(index, ["title", "content"])
      {:ok, query} = TantivyEx.Query.parse(parser, "elixir OR laptop")
      {:ok, results} = Searcher.search(searcher, query, 10)

      processed_results = MyApp.ResultProcessor.process_search_results(results)

      assert length(processed_results) > 0

      # Check that results are properly normalized and sorted
      [first_result | _rest] = processed_results
      # Highest score should be 100%
      assert first_result.normalized_score == 100.0

      # Verify all results have required fields
      Enum.each(processed_results, fn result ->
        assert is_float(result.score)
        assert is_float(result.normalized_score)
        assert is_binary(result.title)
        assert is_binary(result.author)
        assert is_float(result.rating)
        assert is_binary(result.url)
      end)
    end
  end
end
