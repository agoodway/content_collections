defmodule ContentCollections.MixProject do
  use Mix.Project

  def project do
    [
      app: :content_collections,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_coverage: [summary: [threshold: 0]],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [cover: :test, "cover.export": :test]
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
      {:yaml_elixir, "~> 2.11"},
      {:mdex, "~> 0.2"},
      {:phoenix_live_view, "~> 1.1", optional: true},
      {:phoenix_html, "~> 4.1", optional: true}
    ]
  end

  defp aliases do
    [
      cover: ["test --cover"],
      "cover.export": ["test --cover --export-coverage default"]
    ]
  end
end
