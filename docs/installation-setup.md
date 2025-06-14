# Installation & Setup

This guide walks you through installing and setting up TantivyEx in your Elixir project.

## Prerequisites

Before installing TantivyEx, ensure you have:

- **Elixir 1.12+** and **Erlang/OTP 24+**
- **Rust 1.70+** (for compiling the native library)
- **Git** (for dependency management)

## Installation

### Step 1: Add TantivyEx to Dependencies

Add TantivyEx to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:tantivy_ex, "~> 0.1.0"}
  ]
end
```

### Step 2: Install Dependencies

Install dependencies:

```bash
mix deps.get
```

### Step 3: Compile Native Library

Compile the native library (this may take a few minutes on first compile):

```bash
mix compile
```

> **Note**: The first compilation can take 5-10 minutes as it builds the Rust components. Subsequent compilations will be much faster.

## Verification

Verify your installation with a simple test:

```elixir
# In iex -S mix
alias TantivyEx.{Index, Schema}

# Create a simple schema
schema = Schema.new()
schema = Schema.add_text_field(schema, "title", :text)
schema = Schema.add_text_field(schema, "content", :text)

# Create a temporary index
{:ok, index} = Index.create_in_ram(schema)

# Add a document
{:ok, writer} = TantivyEx.IndexWriter.new(index)
doc = %{"title" => "Hello TantivyEx", "content" => "This is a test document"}
:ok = TantivyEx.IndexWriter.add_document(writer, doc)
:ok = TantivyEx.IndexWriter.commit(writer)

# Search
{:ok, searcher} = TantivyEx.Searcher.new(index)
{:ok, results} = TantivyEx.Searcher.search(searcher, "hello", 10)
IO.inspect(results)
# Should return: [%{"title" => "Hello TantivyEx", "content" => "This is a test document"}]
```

If this works without errors, your installation is successful!

## Troubleshooting

### Common Installation Issues

#### Rust Not Found

If you get an error about Rust not being found:

```bash
# Install Rust using rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Verify installation
rustc --version
```

#### Compilation Errors

If you encounter compilation errors:

1. **Update Rust**: `rustup update`
2. **Clean build**: `mix clean && mix deps.clean tantivy_ex --build`
3. **Retry compilation**: `mix compile`

#### Permission Issues

If you get permission errors during compilation:

```bash
# Ensure proper ownership of the project directory
sudo chown -R $USER:$USER /path/to/your/project

# Or use mix with proper permissions
mix deps.get --force
```

## Next Steps

Once TantivyEx is installed and verified:

1. **[Quick Start Tutorial](quick-start.md)** - Build your first search index
2. **[Core Concepts](core-concepts.md)** - Understand TantivyEx fundamentals
3. **[Schema Design Guide](schema.md)** - Design your data structure
4. **[Document Operations Guide](documents.md)** - Work with documents

## Development Setup

For development work on TantivyEx itself:

```bash
# Clone the repository
git clone https://github.com/alexiob/tantivy_ex.git
cd tantivy_ex

# Install dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs
```
