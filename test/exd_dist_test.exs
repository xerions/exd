defmodule ExdDistTest do
  use ExUnit.Case

  import Mock

  setup do
    Application.ensure_all_started(:ecto_it)
    for model <- [City, Weather], do: Exd.Model.compile_migrate(EctoIt.Repo, model, [])
    on_exit fn() -> :application.stop(:ecto_it) end
    :ok
  end

  test_with_mock "remoter", :net_adm, [:unstick, :passthrough], 
    [localhost: fn() -> Atom.to_string(node()) |> String.split("@") |> List.last |> String.to_char_list end] do
     remoter = Exd.Escript.Remoter.get("dist")
     assert ["exd"] = remoter.applications(:test) |> Map.keys 
     api = remoter.applications(:test)["exd"]["city"]
     assert %{"id": 1} = remoter.remote(api, "post", %{"name" => "testcity"})
     assert %{"id": 1} = remoter.remote(api, "delete", %{"id" => 1})
     assert nil = remoter.remote(api, "get", %{"id" => 1})
  end
end
