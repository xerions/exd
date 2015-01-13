defmodule Exd.Mixfile do
  use Mix.Project

  def project do
    [app: :exd,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
     deps: deps,
     compilers: [:erlang, :elixir, :app]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger],
     mod: {Exd, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:mariaex, ">= 0.0.0"},
     {:ecto, "~> 0.9"}]
  end
end
