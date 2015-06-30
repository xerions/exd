defmodule ExdHelloTest do
  use ExUnit.Case

  setup do
    Application.ensure_all_started(:hello)
    Application.ensure_all_started(:ecto_it)
    Exd.Plugin.Hello.start_listener('zmq-tcp://127.0.0.1:10900')
    for model <- [City, Weather], do: Exd.Model.compile_migrate(EctoIt.Repo, model, [])
    for api <- [City.Api, Weather.Api], do: :hello.bind('zmq-tcp://127.0.0.1:10900', api)
    :hello_client.start({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', [], [decoder: :hello_json], [])
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
    :hello_client.call(__MODULE__, {method, Map.put(params, "resource", resource), []})
  end
end
