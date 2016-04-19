defmodule ExdDistTest do
  use ExUnit.Case

  import Mock

  setup do
    Application.ensure_all_started(:ecto_it)
    for model <- [City, Weather], do: Exd.Model.compile_migrate(EctoIt.Repo, model, [])
    Ecto.Migration.Auto.migrate(EctoIt.Repo, Ecto.Taggable, [for: Elixir.City])
    on_exit fn() -> :application.stop(:ecto_it) end
    :ok
  end

  test_with_mock "remoter", :net_adm, [:unstick, :passthrough], 
    [localhost: fn() -> Atom.to_string(node()) |> String.split("@") |> List.last |> String.to_char_list end] do
     remoter = Exd.Escript.Remoter.get("dist")

     # This will initialize the metrics for the city api on top of the native metrics.
     Exd.Metrics.init_metrics(City.Api)

     %{"id": val} = remoter.remote("exd/city", "post", %{"name" => "testcity"})
     assert 1 = val

     # Check the metrics for the first single request.
     # There is one initial request included in the request counters,
     # therefore we get '2' requests where the method is 'total'.
     assert {:ok,[{:value, 2}, _]} = :exometer.get_value([:exd,:request,:total,:city,:total,:counter])
     assert {:ok,[{:value, 2}, _]} = :exometer.get_value([:exd,:request,:total,:city,:success,:counter])
     assert {:ok,[{:value, 1}, _]} = :exometer.get_value([:exd,:request,:post,:city,:success,:counter])
     assert {:ok,[{:value, total}, _]} = :exometer.get_value([:exd,:request,:total,:total,:total,:counter])
     assert {:ok,[{:value, total_success}, _]} = :exometer.get_value([:exd,:request,:total,:total,:success,:counter])
     assert true = total > 0
     assert true = total_success > 0

     # Since a city is inserted there is a city object in the database
     assert {:ok,[value: 1]} = :exometer.get_value([:exd,:object,:city,:counter])

     tag = remoter.remote("exd/city/tag", "post", %{"name" => "testcity", "tag" => "tag1", "tag_value" => "tag_for_city"})
     assert %{id: 1} == tag

     tag = remoter.remote("exd/city/tag", "get", %{"tag" => "tag1", "tag_value" => "tag_for_city"})
     assert "testcity" == tag.name

     tag = remoter.remote("exd/city/tag", "delete", %{"name" => "testcity", "tag" => "tag1", "tag_value" => "tag_for_city"})
     assert %{id: 1} == tag

     %{"id": val} = remoter.remote("exd/city", "delete", %{"id" => 1})
     assert 1 = val
  end
end
