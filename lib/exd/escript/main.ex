defmodule Exd.Escript.Main do
  
  @parse_opts [switches: [formatter: :string, input: :string, remoter: :string]]

  def main(args) do
    {opts, args, _} = OptionParser.parse(args, @parse_opts)
    remoter = Exd.Escript.Remoter.get( opts[:remoter] || "dist" ) || fail("remoter: #{opts[:remoter]} not supported")
    local_apps = remoter.applications(script())
    main(args, opts, remoter, local_apps)
  end


  defp main([], _opts, _remoter, local_apps) do
    apps = local_apps |> Stream.map(&elem(&1, 0)) |> Enum.join(", ") 
    example_app = map_key(local_apps, "app")
    example_api = local_apps[example_app] |> map_key("api")
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

  defp main([command], opts, remoter, local_apps) do
    IO.puts "Error: 'exd #{command}' command must have options"
    main([], opts, remoter, local_apps)
  end

  defp main([command, link | payload], opts, remoter, local_apps) do
    [app | link_rest] = String.split(link, "/")
    app_api = local_apps[app] || fail("application: #{app} not found")
    on_app(command, opts, link_rest, payload, app_api, remoter)
  end

  defp on_app("options", _opts, [], _, app, _remoter) do
    IO.puts """
link: #{app[:name]}

available apis:
#{ Enum.map(app, &print_api(&1, app[:name]))}
"""
  end

  defp on_app(command, opts, [api], payload, app, remoter) do
    api_map = app[api] || fail("application: #{app[:name]}: api #{api} not found")
    IO.puts("link: #{app[:name]}/#{api}")
    on_command(command, opts, api_map, payload, remoter)
  end

  defp on_command(command, opts, api, payload, remoter) do
    payload_map = payload(payload, opts[:input] || "native")
    result = remoter.remote(api, command, payload_map)
    result_to_string(command, opts[:formatter] || "native", result) |> IO.puts
  end

  defp print_api({_, %{name: name, desc_name: desc_name, description: doc}}, app) do
    "  #{name} - #{desc_name}: #{doc}    example: #{script} option #{app}/#{name}"
  end
  defp print_api(_, _), do: []

  defp result_to_string(_command, "native", result), do: "#{inspect result}"
  defp result_to_string(_command, "json", result), do: Poison.encode!(result) |> :jsx.prettify

  defp payload(payload, "native") do
    splited = Enum.map(payload, &String.split(&1, ":", parts: 2))
    Enum.all?(splited, &((length(&1) == 2) or (length(&1) == 3))) || fail("payload should be in form of <key>:<value> or <key>:<value>:<meta>")
    splited |> Enum.map(&List.to_tuple/1) |> Enum.into(%{})
  end

  defp script, do: :escript.script_name |> Path.basename |> String.to_atom

  defp map_key(map, _default) when map_size(map) > 0, do: map |> Map.keys |> hd()
  defp map_key(_map, default), do: default

  defp fail(message) do
    IO.puts(message)
    :erlang.halt(1)
  end
end
