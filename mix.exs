defmodule Cucumberex.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :cucumberex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Full-featured Cucumber/BDD framework for Elixir",
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Cucumberex.Application, []}
    ]
  end

  defp deps do
    [
      {:cucumber_gherkin, "~> 39.0"},
      {:cucumber_messages, "~> 32.0"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:nimble_options, "~> 1.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jeffreybaird/cucumberex"},
      maintainers: ["Jeffrey Baird"],
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
