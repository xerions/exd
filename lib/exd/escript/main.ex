defmodule Exd.Escript.Main do
  
  @parse_opts [switches: [formatter: :string, input: :string, remoter: :string]]

  def main(args) do
    {opts, args, _} = OptionParser.parse(args, @parse_opts)
    remoter = Exd.Escript.Remoter.get( opts[:remoter] || "dist" ) || fail("remoter: #{opts[:remoter]} not supported")
    case args do
      ["options", app] ->
        remoter.remote(app <> "/", "options", %{}) |> options(app)
      [method, path | params] ->
        result = remoter.remote(path, method, payload(params, opts[:input] || "native"))
        result_to_string(method, opts[:formatter] || "native", result) |> IO.puts
      _ ->
        main([], remoter.remote("exd/", "help", %{}))
    end
  end

  defp main([], local_apps) do
    apps  = local_apps |> Enum.filter(fn(app) -> map_size(app) > 0 end) |> Enum.map(fn(app) -> app[:app] end) |> Enum.join(", ")
    {example_app, example_api} = case local_apps do
      [] -> {:app, :api}
      _ ->
        app = Enum.at(local_apps, 0)
        {app[:app], first_model(app)}
      end
    link = "#{ example_app }/#{ example_api }"
    script = script()
    IO.puts """
usage: #{script} <command> <link> <data...> <opts...>

commands:
  options - introspection of resources
  get     - get actual resource
  post    - create resource
  put     - update existing resource
  delete  - delete a resource

link:
  <app>
  <app>/<model>

data: should be given in input format(defaults to native: <key>:<value>)

available applications: #{apps}

example of usage:

  #{script} options #{example_app}
  #{script} options #{link}
  #{script} get #{link} id:1
  #{script} get #{link} where:"id < 10 and id > 1" limit:5 offset:5
  #{script} get #{link} where:"id < 10" order_by:"id:desc" limit:5 offset:5
  #{script} get #{link} join:"my_model, my_model2" where:"my_model.id == 10 or my_model.id == 15"
  #{script} get #{link} join:"my_model, my_model2" where:"my_model.id == 10" select:"name,my_model2.name"
  #{script} get #{link} join:"my_model, my_model2" where:"my_model.id == 10" count:"my_model2.name"
  #{script} get #{link} join:"my_model, my_model2" where:"my_model.id == 10" min:"my_model2.name"
  #{script} post #{link} key:value
  #{script} put #{link} id:1 key:value
  #{script} delete #{link} id:1

aliases:

  #{script} list #{link}

available opts:

  --formatter native|json - formats the reply, defaults to native
  --input native|json - payload input format, defaults to native
  --remoter dist|zmtp - transport to communicate remote services
"""
  end

  defp options(result, app) do
    Enum.filter(result, fn(app) -> map_size(app) > 0 end) != [] || fail("application: #{app} not found")
    Enum.map(result, fn(res) ->
      if map_size(res) != 0 do
        api = first_model(res)
        IO.puts """
link: #{res[:name]}

apis:
  #{res[:name]} - #{res[:description]}
    Usage: #{script} option #{res[:app]}/#{api} (get|post|put|delete) [payload]
"""
      end
    end)
  end

  defp result_to_string(_command, "native", result), do: "#{inspect result}"
  defp result_to_string(_command, "json", result), do: Poison.encode!(result) |> :jsx.prettify

  defp payload(payload, "native") do
    splited = Enum.map(payload, &String.split(&1, ":", parts: 2))
    Enum.all?(splited, &((length(&1) == 2) or (length(&1) == 3))) || fail("payload should be in form of <key>:<value> or <key>:<value>:<meta>")
    splited |> Enum.map(&List.to_tuple/1) |> Enum.into(%{})
  end

  defp script, do: :escript.script_name |> Path.basename |> String.to_atom

  defp fail(message) do
    IO.puts(message)
    :erlang.halt(1)
  end

  defp first_model(app) do
    Enum.filter(app, fn({k, _}) -> is_binary(k) end) |> List.first |> elem(0)
  end
end
