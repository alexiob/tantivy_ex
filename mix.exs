defmodule TantivyEx.MixProject do
  use Mix.Project

  @version "0.3.3"
  @source_url "https://github.com/alex-nexus/tantivy_ex"

  def project do
    [
      app: :tantivy_ex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      rustler_crates: rustler_crates(),
      deps: deps(),

      # Hex.pm package information
      package: package(),
      description: description(),

      # Documentation
      name: "TantivyEx",
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :sasl, :os_mon]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler_precompiled, "~> 0.4"},
      {:rustler, "~> 0.36.1"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:igniter, "~> 0.6", optional: true},
      {:jason, "~> 1.4"}
    ]
  end

  defp rustler_crates do
    [
      tantivy_ex: [path: "native/tantivy_ex", mode: rustler_mode()]
    ]
  end

  defp rustler_mode do
    case Mix.env() do
      :prod -> :release
      _ -> :debug
    end
  end

  defp description do
    "A comprehensive Elixir wrapper for the Tantivy full-text search engine, providing high-performance search capabilities with support for all field types, custom tokenizers, and advanced indexing features."
  end

  defp package do
    [
      name: "tantivy_ex",
      files: ~w(lib priv native/tantivy_ex/src native/tantivy_ex/Cargo.toml native/tantivy_ex/Cargo.lock native/tantivy_ex/Cross.toml docs .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Guides" => "#{@source_url}/tree/main/docs"
      },
      submitter: "alexiob",
      maintainer: "alessandro@iob.dev"
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      assets: %{"docs/assets" => "assets"},
      extras: [
        "README.md",
        "CHANGELOG.md",
        "DEVELOPMENT.md",
        "LICENSE",
        "docs/installation-setup.md",
        "docs/quick-start.md",
        "docs/core-concepts.md",
        "docs/guides.md",
        "docs/schema.md",
        "docs/documents.md",
        "docs/indexing.md",
        "docs/search.md",
        "docs/search_results.md",
        "docs/tokenizers.md",
        "docs/aggregations.md",
        "docs/otp-distributed-implementation.md",
        "docs/integration-patterns.md",
        "docs/performance-tuning.md",
        "docs/production-deployment.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/.*/
      ],
      groups_for_modules: [
        Core: [TantivyEx, TantivyEx.Native],
        Schema: [TantivyEx.Schema],
        "Data Types": []
      ]
    ]
  end
end
