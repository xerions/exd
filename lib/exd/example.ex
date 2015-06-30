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
      field :city_id, :integer
      field :name, :string
      field :country, :string
    end
  end

  defmodule Weather.Api do
    @moduledoc "Weather API documentation"
    @name "Weather"
    @tech_name "weather"
    use Exd.Api, model: Weather, repo: EctoIt.Repo
    crud

    require Exd.Plugin.Hello
    Exd.Plugin.Hello.def_service(:weather)
  end

  defmodule City.Api do
    @moduledoc "City API documentation"
    @name "City"
    @tech_name "weather"
    use Exd.Api, model: City, repo: EctoIt.Repo
    crud
  end

end
