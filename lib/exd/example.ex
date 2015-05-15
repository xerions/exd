if Mix.env == :test do
  import Exd.Model
  model Weather do
    schema "weather" do
      field :city
      field :temp_lo, :integer
      field :temp_hi, :integer
      field :prcp,    :float, default: 0.0
      timestamps
    end
  end

  defmodule Weather.Api do
    @moduledoc "Weather API documentation"
    @name "Weather"
    @tech_name "weather"
    use Exd.Api, model: Weather, repo: EctoIt.Repo
    crud
  end
end
