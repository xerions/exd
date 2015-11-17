defmodule ExdHelloTest do
  use ExUnit.Case

  setup do
    Application.ensure_all_started(:hello)
    Application.ensure_all_started(:ecto_it)
    Exd.Plugin.Hello.start_listener('zmq-tcp://127.0.0.1:10900', :test)
    for model <- [City, Weather] do
      Exd.Model.compile_migrate(EctoIt.Repo, model, [])
      assocs = model.__schema__(:associations)
      tags = Enum.filter(assocs, fn(assoc) ->
        model.__schema__(:association, assoc).related == :'Elixir.Ecto.Taggable'
      end)
      if length(tags) == 1 do
        Ecto.Migration.Auto.migrate(EctoIt.Repo, Ecto.Taggable, [for: model])
      end
    end
    for api <- [City.Api, Weather.Api], do: Hello.bind('zmq-tcp://127.0.0.1:10900', api)
    Hello.bind('zmq-tcp://127.0.0.1:10900', Exd.Api.Tag, %{repo: EctoIt.Repo})
    Hello.Client.start({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', [], [], [])
    on_exit fn() ->
      :application.stop(:hello)
      :application.stop(:ecto_it)
    end
    :ok
  end

  test "hello client" do
    # create
    assert {:ok, %{"id" => id}} = call("post", "city", %{"name" => "Berlin"})
    assert {:ok, %{"id" => _}} = call("post", "city", ["country": "Germany", "name": "Hamburg"])
    assert {:ok, %{"id" => nid}} = call("post", "city", %{"country" => "Russia", "name" => "Novosibirsk"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "Russia", "name" => "Moscow"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "Russia", "name" => "Omsk"})
    assert {:ok, %{"id" => _}} = call("post", "city", %{"country" => "UK", "name" => "London"})
    assert {:ok, %{"id" => wid}} = call("post", "weather", %{"name" => "Weather", "city_id" => id, "temp_lo" => 15})
    assert {:ok, %{"id" => _}} = call("post", "weather", %{"name" => "Weather1", "city_id" => nid, "temp_lo" => -30})

    # get
    assert {:ok, %{"country" => :null, "name" => "Berlin"}} = call("get", "exd/city", %{"name" => "Berlin"})
    assert {:ok, %{"country" => :null, "weather" => [%{"temp_hi" => :null, "temp_lo" => 15}]}}
           = call("get", "exd/city", %{"name" => "Berlin", "load" => ["weather"]})

    # count
    assert {:ok, [%{"count" => 1}]} = call("get", "exd/city", %{"where" => "country == \"UK\"", "count" => "id"})
    assert {:ok, [%{"count" => 3}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"", "count" => "id"})

    # where
    assert {:ok, [%{"name" => "Novosibirsk"},
                  %{"name" => "Moscow"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\""})
    assert {:ok, [%{"name" => "London"}]} = call("get", "exd/city", %{"where" => "country == \"UK\""})
    # offsets
    assert {:ok, [%{"name" => "Novosibirsk"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"",
                                                                           "limit" => 1, "offset" => 0})
    assert {:ok, [%{"name" => "Moscow"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"",
                                                                      "limit" => "1", "offset" => "1"})
    assert {:ok, [%{"name" => "Omsk"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"",
                                                                    "limit" => 1, "offset" => 2})
    # like
    assert {:ok, [%{"name" => "Novosibirsk"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"where" => "like(name, \"%sk%\")"})
    assert {:ok, [%{"name" => "Omsk"}]} = call("get", "exd/city", %{"where" => "like(name, \"%msk\")"})
    assert {:ok, [%{"name" => "Berlin"}]} = call("get", "exd/city", %{"where" => "like(name, \"b%\")"})
    assert {:ok, [%{"name" => "Berlin"}]} = call("get", "exd/city", %{"where" => "like(name, \"berlin\")"})

    # distinct
    assert {:ok, [%{"country" => :null},
                  %{"country" => "Germany"},
                  %{"country" => "Russia"},
                  %{"country" => "UK"}]} = call("get", "exd/city", %{"select" => "country", "distinct" => true})

    # order
    assert {:ok, [%{"name" => "Moscow"},
                  %{"name" => "Novosibirsk"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"",
                                                                    "order_by" => "name"})
    assert {:ok, [%{"name" => "Omsk"},
                  %{"name" => "Novosibirsk"},
                  %{"name" => "Moscow"}]} = call("get", "exd/city", %{"where" => "country == \"Russia\"",
                                                                      "order_by" => "name:desc"})

    # join
    assert {:ok, [%{"city.name" => "Novosibirsk", "weather.temp_lo" => -30}]}
            = call("get", "exd/city", %{"where" => "city.name == \"Novosibirsk\"",
                                        "join" => ["city","weather"], "select" => "city.name,weather.temp_lo"})

    # update
    assert {:ok, %{"id" => wid}} = call("put", "exd/weather", %{"id" => wid, "temp_lo" => 14, "temp_hi" => 25})
    assert {:ok, %{"temp_lo" => 14, "temp_hi" => 25}} = call("get", "exd/weather", %{"id" => wid})

    # search
    assert {:ok, [%{"name" => "Novosibirsk"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"search" => "%sk%"})
    assert {:ok, [%{"name" => "Berlin"},
                  %{"name" => "Novosibirsk"},
                  %{"name" => "Moscow"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"search" => "%i%"})
    assert {:ok, [%{"name" => "Novosibirsk"},
                  %{"name" => "Moscow"},
                  %{"name" => "Omsk"}]} = call("get", "exd/city", %{"search" => "%i%", "where" => "country == \"Russia\""})

    # delete
    assert {:ok, %{"id" => wid}} = call("delete", "exd/weather", %{"id" => wid})
    assert {:ok, %{"id" => id}} = call("delete", "exd/city", %{"id" => id})
    assert {:ok, :null} = call("get", "exd/weather", %{"id" => wid})
    assert {:ok, :null} = call("get", "exd/city", %{"id" => id})

    # tags
    assert {:ok, %{"id" => id}} = call("post", "exd/city", %{"name" => "TestCity_Tags1"})
    assert {:ok, %{"id" => id}} = call("post", "exd/city", %{"name" => "TestCity_Tags2"})
    assert {:ok, %{"id" => 1}} = call("post", "exd/city/tag", %{"name" => "TestCity_Tags1", "tag" => "city_tag_1"})
    assert {:ok, %{"id" => 2}} = call("post", "exd/city/tag", %{"name" => "TestCity_Tags2", "tag" => "city_tag_1"})
    {:ok, cities_with_tags} = call("get",  "exd/city/tag", %{"tag" => "city_tag_1"})
    assert 2 = length(cities_with_tags)
    [city1, city2] = cities_with_tags
    assert "TestCity_Tags1" = city1["name"]
    assert "TestCity_Tags2" = city2["name"]

    assert {:ok, %{"id" => 2}} = call("delete", "exd/city/tag", %{"name" => "TestCity_Tags2", "tag" => "city_tag_1"})
    {:ok, cities_with_tags} = call("get",  "exd/city/tag", %{"tag" => "city_tag_1"})
    assert 1 = length(cities_with_tags)
    [city1] = cities_with_tags
    assert "TestCity_Tags1" = city1["name"]
    {:ok, city2_after_tag_remove} = call("get", "exd/city", %{"name" => "TestCity_Tags2"})
    assert null = city2_after_tag_remove["country"]
    assert "TestCity_Tags2" = city2_after_tag_remove["name"]

    assert {:ok, %{"id" => _}} = call("post", "city", %{"name" => "Magdeburg"})
    assert {:ok, %{"errors" => %{"name" => "exists"}}} = call("post", "city", %{"name" => "Magdeburg"})
    assert {:ok, %{"errors" => %{"city_id" => "not found"}}} = call("post", "weather", %{"name" => "WeatherX", "city_id" => 99999, "temp_lo" => 15})
  end

  defp call(method, resource, params) when is_map(params) do
    Hello.Client.call(__MODULE__, {method, Map.put(params, "resource", resource), []})
  end
  defp call(method, resource, params) when is_list(params) do
    Hello.Client.call(__MODULE__, {method, params ++ ["resource": resource], []})
  end
end
