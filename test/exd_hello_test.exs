defmodule ExdHelloTest do
  use ExUnit.Case

  setup do
    Application.ensure_all_started(:hello)
    Application.ensure_all_started(:ecto_it)
    Exd.Plugin.Hello.start_listener('zmq-tcp://127.0.0.1:10900')
    for model <- [City, Weather], do: Exd.Model.compile_migrate(EctoIt.Repo, model, [])
    for api <- [City.Api, Weather.Api], do: Hello.bind('zmq-tcp://127.0.0.1:10900', api)
    Hello.Client.start({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', [], [], [])
    on_exit fn() -> :application.stop(:ecto_it) end
    :ok
  end

  test "test null" do
    assert {:ok, %{"id" => id}} = call("post", "city", %{"name" => "Berlin"})
    assert {:ok, %{"country" => :null, "name" => "Berlin"}} = call("get", "city", %{"name" => "Berlin"})
    assert {:ok, %{"id" => _}} = call("post", "weather", %{"name" => "Weather", "city_id" => id, "temp_lo" => 15})
    assert {:ok, %{"country" => :null, "weathers" => [%{"temp_hi" => :null, "temp_lo" => 15}]}} = call("get", "city", %{"name" => "Berlin", "load" => ["weathers"]})
  end

  defp call(method, resource, params) do
    Hello.Client.call(__MODULE__, {method, Map.put(params, "resource", resource), []})
  end
end
