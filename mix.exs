defmodule TantivyEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :tantivy_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      # Remove the rustler compiler since we're handling load directly
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
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
end
