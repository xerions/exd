defmodule ExdTest do
  use ExUnit.Case
  doctest Exd.Model

  test "introspection" do
    weather = Exd.Api.introspection(Weather.Api)
    city = Exd.Api.introspection(City.Api)
    assert "Weather API documentation" = weather[:description]
    assert "City API documentation" = city[:description]

    assert "Weather" = weather[:desc_name]
    assert "City" = city[:desc_name]

    method = ["options", "post", "put", "get", "delete"]
    assert [] = method -- weather[:methods]
    assert [] = method -- city[:methods]

    check_weather_fields(weather[:fields])
    check_city_fields(weather[:fields])
  end

  defp check_weather_fields(fields0) do
    fields = [
      %{datatype: :id, description: "", name: :id, relation: "", type: :read_only},
      %{datatype: :id, description: "", name: :city_id, relation: "city", type: :mandantory},
      %{datatype: :string, description: "", name: :name, relation: "", type: :mandantory},
      %{datatype: :integer, description: "", name: :temp_lo, relation: "", type: :optional},
      %{datatype: :integer, description: "", name: :temp_hi, relation: "", type: :optional},
      %{datatype: :float, description: "", name: :prcp, relation: "", type: :optional},
      %{datatype: Ecto.DateTime, description: "", name: :inserted_at, relation: "", type: :read_only},
      %{datatype: Ecto.DateTime, description: "", name: :updated_at, relation: "", type: :read_only}]
    assert fields = fields0
  end

  defp check_city_fields(fields0) do
    fields = [
      %{datatype: :id, description: "", name: :id, relation: "", type: :read_only},
      %{datatype: :string, description: "", name: :name, relation: "", type: :mandantory},
      %{datatype: :string, description: "", name: :country, relation: "", type: :optional}]
    assert fields = fields0
  end
end
