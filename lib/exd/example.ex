if Mix.env in [:dev, :test] do
  import Exd.Model
  model Weather do
    schema "weather" do
      belongs_to :city, City
      field :name, :string
      field :temp_lo, :integer
      field :temp_hi, :integer
      field :prcp,    :float, default: 0.0
      timestamps
    end
  end

  model City do
    schema "city" do
      field :name, :string
      field :country, :string
      has_many :weather, Weather
    end
  end

  import Exd.Plugin.Hello

  defmodule Weather.Api do
    @moduledoc "Weather API documentation"
    @name "Weather"
    @tech_name "weather"
    @optional [:prcp, :temp_lo, :temp_hi]
    use Exd.Api, model: Weather, repo: EctoIt.Repo
    crud
    def_service(:test_app)
  end

  defmodule City.Api do
    @moduledoc "City API documentation"
    @name "City"
    @tech_name "city"
    @optional [:country]
    @search [:name, :country]
    use Exd.Api, model: City, repo: EctoIt.Repo
    crud
    def_service(:test_app)
  end

  defmodule Example.Api do
    @moduledoc "Example application"
    @name "Example"
    @tech_name "exd"
    @app true
    use Exd.Api, apis: [City.Api, Weather.Api]
  end
end
