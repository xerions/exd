defmodule ExdZmtpTest do
  use ExUnit.Case

  setup do
    Application.ensure_all_started(:ecto_it)
    Application.ensure_all_started(:hello)
    Exd.Plugin.Hello.start_listener('zmq-tcp://127.0.0.1:10900')
    for model <- [City, Weather], do: Exd.Model.compile_migrate(EctoIt.Repo, model, [])
    :hello.bind('zmq-tcp://127.0.0.1:10900', City.Api)
    on_exit fn() ->
      :application.stop(:ecto_it)
      :application.stop(:hello)
    end
    :ok
  end

  test "test zmtp" do
      remoter = Exd.Escript.Remoter.get("zmtp")
      [apps] = remoter.applications(:test)
      api = apps["exd"]["city"]
      assert %{"id" => 1} = remoter.remote(api, "post", %{"name" => "testcity1"})
      assert %{"id" => 2} = remoter.remote(api, "post", %{"name" => "testcity2"})
      assert %{"country" => "nil", "id" => 1, "name" => "testcity1"} = remoter.remote(api, "get", %{"id" => 1})
  end
end
