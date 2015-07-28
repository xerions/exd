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

  test "hello client" do
    # create
    assert {:ok, %{"id" => id}} = call("post", "city", %{"name" => "Berlin"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "Germany", "name" => "Hamburg"})
    assert {:ok, %{"id" => nid}} = call("post", "city", %{"country" => "Russia", "name" => "Novosibirsk"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "Russia", "name" => "Moscow"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "Russia", "name" => "Omsk"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "UK", "name" => "London"})
    assert {:ok, %{"id" => wid}} = call("post", "weather", %{"name" => "Weather", "city_id" => id, "temp_lo" => 15})
    assert {:ok, %{"id" => _}} = call("post", "weather", %{"name" => "Weather1", "city_id" => nid, "temp_lo" => -30})

    # get
    assert {:ok, %{"country" => :null, "name" => "Berlin"}} = call("get", "city", %{"name" => "Berlin"})
    assert {:ok, %{"country" => :null, 
                   "weather" => [%{"temp_hi" => :null, "temp_lo" => 15}]
                 }} = call("get", "city", %{"name" => "Berlin", "load" => ["weather"]})

    # count
    assert {:ok, [%{"count" => 1}]} = call("get", "city", %{"where" => "country == \"UK\"", "count" => "id"})
    assert {:ok, [%{"count" => 3}]} = call("get", "city", %{"where" => "country == \"Russia\"", "count" => "id"})

    # where
    assert {:ok, [%{"name" => "Novosibirsk"}, 
                  %{"name" => "Moscow"},
                  %{"name" => "Omsk"}]} = call("get", "city", %{"where" => "country == \"Russia\""})
    assert {:ok, [%{"name" => "London"}]} = call("get", "city", %{"where" => "country == \"UK\""})
    # offsets
    assert {:ok, [%{"name" => "Novosibirsk"}]} = call("get", "city", %{"where" => "country == \"Russia\"",
                                                                       "limit" => 1, "offset" => 0})
    assert {:ok, [%{"name" => "Moscow"}]} = call("get", "city", %{"where" => "country == \"Russia\"",
                                                                  "limit" => 1, "offset" => 1})
    assert {:ok, [%{"name" => "Omsk"}]} = call("get", "city", %{"where" => "country == \"Russia\"",
                                                                "limit" => 1, "offset" => 2})

    # order
    assert {:ok, [%{"name" => "Moscow"}, 
                  %{"name" => "Novosibirsk"},
                  %{"name" => "Omsk"}]} = call("get", "city", %{"where" => "country == \"Russia\"", 
                                                                "order_by" => "name"})

    # join
    assert {:ok, [%{"name" => "Novosibirsk", "weather.temp_lo" => -30}]} 
            = call("get", "city", %{"where" => "city.name == \"Novosibirsk\"",
                                    "join" => "city, weather", "select" => "city.name, weather.temp_lo"})

    # update
    assert {:ok, %{"id" => wid}} = call("put", "weather", %{"id" => wid, "temp_lo" => 14, "temp_hi" => 25})
    assert {:ok, %{"temp_lo" => 14, "temp_hi" => 25}} = call("get", "weather", %{"id" => wid})

    # delete
    assert {:ok, %{"id" => wid}} = call("delete", "weather", %{"id" => wid})
    assert {:ok, %{"id" => id}} = call("delete", "city", %{"id" => id})
    assert {:ok, :null} = call("get", "weather", %{"id" => wid})
    assert {:ok, :null} = call("get", "city", %{"id" => id})
  end

  defp call(method, resource, params) do
    Hello.Client.call(__MODULE__, {method, Map.put(params, "resource", resource), []})
  end
end
