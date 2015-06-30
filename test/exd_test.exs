defmodule ExdTest do
  use ExUnit.Case
  doctest Exd.Model

  test "test" do
    assert "Weather API documentation" = Apix.spec(Weather.Api, :doc)

  end
end
