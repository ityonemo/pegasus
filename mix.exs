defmodule Pegasus.MixProject do
  use Mix.Project

  def project do
    [
      app: :pegasus,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def elixirc_paths(:test), do: ["lib", "test/_support"]
  def elixirc_paths(_), do: ["lib"]

  defp deps do
    [nimble_parsec: "~> 1.2"]
  end
end
