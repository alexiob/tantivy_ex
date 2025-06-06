#!/usr/bin/env elixir

# Quick test script to verify MoreLikeThisQuery functionality
Mix.install([
  {:tantivy_ex, path: "."}
])

alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

# Create a test schema
schema = Schema.new()
|> Schema.add_text_field("title", stored: true)
|> Schema.add_text_field("content", stored: true)

# Create an in-memory index
{:ok, index} = Index.create_in_ram(schema)

# Create a writer and add some documents
{:ok, writer} = IndexWriter.new(index, 50_000_000)

documents = [
  %{"title" => "Rust Programming", "content" => "Rust is a systems programming language that is fast and memory safe"},
  %{"title" => "Elixir Guide", "content" => "Elixir is a functional programming language built on the Erlang VM"},
  %{"title" => "Systems Programming", "content" => "Systems programming involves writing software that provides services to other software"},
  %{"title" => "Memory Safety", "content" => "Memory safety is crucial in systems programming to prevent crashes and security vulnerabilities"}
]

# Add documents to the index
Enum.each(documents, fn doc ->
  IndexWriter.add_document(writer, Jason.encode!(doc))
end)

# Commit the changes
IndexWriter.commit(writer)

# Create a searcher
{:ok, searcher} = Searcher.new(index)

# Test MoreLikeThisQuery
test_document = %{"title" => "Programming Languages", "content" => "Programming languages for system development"}

IO.puts("Testing MoreLikeThisQuery...")

case Query.more_like_this(schema, Jason.encode!(test_document), min_doc_frequency: 1, max_query_terms: 10) do
  {:ok, query} ->
    IO.puts("✅ MoreLikeThisQuery created successfully!")

    case Searcher.search(searcher, query, 10, true) do
      {:ok, results} ->
        IO.puts("✅ Search completed successfully!")
        IO.puts("Found #{length(results)} results:")

        Enum.with_index(results, 1) do |{result, idx}|
          IO.puts("  #{idx}. Score: #{result["score"]}, Doc: #{inspect(result)}")
        end

      {:error, reason} ->
        IO.puts("❌ Search failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("❌ MoreLikeThisQuery creation failed: #{reason}")
end

IO.puts("\n🎉 MoreLikeThisQuery test completed!")
