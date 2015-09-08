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
     %{"id": val} = remoter.remote("exd/city", "post", %{"name" => "testcity"})
     assert 1 = val

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
