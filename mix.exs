defmodule Exd.Mixfile do
  use Mix.Project

  def project do
    [app: :exd,
     version: "0.1.0-dev",
     elixir: "~> 1.1-dev",
     deps: deps,
     compilers: [:erlang, :elixir, :app]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :ecto, :ecto_migrate, :apix],
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
    [{:postgrex, ">= 0.0.0", optional: true},
     {:jsx, github: "liveforeverx/jsx", branch: "mix_compile", override: true},
     {:mariaex, ">= 0.1.0", optional: true},
     {:ecto_it, "~> 0.1.0", optional: true},
     {:hello, github: "travelping/hello", branch: "hello_v3", optional: true},

     {:lager, "~> 2.1.1", override: true},
     {:exscript, "~> 0.0.1"},
     {:apix, "~> 0.1.0"},
     {:ecto, "~> 0.11.0"},
     {:ecto_migrate, "~> 0.1.0"},
     {:poison, "~> 1.4.0"},

     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.7", only: :dev}]
  end
end
