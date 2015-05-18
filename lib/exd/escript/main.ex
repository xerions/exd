defmodule Exd.Escript.Main do
  @parse_opts [switches: [formatter: :string, input: :string, remoter: :string]]
  def main(args) do
    {opts, args, _} = OptionParser.parse(args, @parse_opts)
    remoter = Exd.Escript.Remoter.get( opts[:remoter] || "dist" ) || fail("remoter: #{opts[:remoter]} not supported")
    local_apps = remoter.applications()
    main(args, opts, script, remoter, local_apps)
  end

  def main([], _opts, script, _remoter, local_apps) do
    apps = local_apps |> Stream.map(&elem(&1, 0)) |> Enum.join(", ")
    example_app = map_key(local_apps, "app")
    example_api = local_apps[example_app] |> map_key("api")
    link = "#{ example_app }/#{ example_api }"
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
  #{script} get #{link} where:"id < 10" limit:5 offset:5
  #{script} post #{link} key:value
  #{script} update #{link} id:1 key:value
  #{script} delete #{link} id:1

aliases:

  #{script} list #{link}

available opts:

  --formatter native|json - formats the reply, defaults to native
  --input native|json - payload input format, defaults to native
  --remoter dist|zmtp - transport to communicate remote services
"""
  end

  def main([command, link | payload], opts, script, remoter, local_apps) do
    [app | link_rest] = String.split(link, "/")
    apis = local_apps[app] || fail("application: #{app} not found")
    on_app(command, opts, app, link_rest, payload, apis, script, remoter)
  end

  #defp main(node, _model, api, "list", []) do
  #  select(node, api, %{})
  #end

  #defp main(node, _, api, "subscribe", ["where" | subscription_info]) do
  #  sub_info = Enum.reduce(subscription_info, "", fn(info, acc) -> info <> " " <> acc <> " " end) |> String.rstrip
  #  rpc(node, api.subscribe(sub_info, [adapter: Ecto.Subscribe.Adapter.Remote, receiver: node()])) |> IO.inspect
  #  :timer.sleep(:infinity)
  #end

  defp on_app("options", _opts, app, [], _, apis, script, _remoter) do
    IO.puts """
link: #{app}

available apis:
#{ Enum.map(apis, &print_api(&1, script)) }
"""
  end

  defp on_app(command, opts, app, [api], payload, apis, script, remoter) do
    api_map = apis[api] || fail("application: #{app}: api #{api} not found")
    IO.puts("link: #{app}/#{api}")
    on_command(command, opts, api_map, payload, script, remoter)
  end

  defp on_command(command, opts, api, payload, _script, remoter) do
    payload_map = payload(payload, opts[:input] || "native")
    result = remoter.remote(api, command, payload_map)
    result_to_string(command, opts[:formatter] || "native", result) |> IO.puts
  end

  defp print_api({tech_name, %{app: app, name: name, doc: doc}}, script) do
    "  #{tech_name} - #{name}: #{doc}    example: #{script} option #{app}/#{tech_name}"
  end

  defp result_to_string(_command, "native", result) do
    "#{inspect result}"
  end

  defp result_to_string(_command, "json", result) do
    Poison.encode!(result) |> :jsx.prettify
  end

  #defp select(node, api, query_content) do
  #  case rpc(node, api.select_on(query_content)) do
  #    [] ->
  #      IO.puts "Nothing found"
  #    query_result ->
  #      fields = rpc(node, api.__schema__(:fields))
  #      String.duplicate("-", 80) |> IO.puts
  #      for row <- query_result, do: print_row(row, fields)
  #      String.duplicate("-", 80) |> IO.puts
  #  end
  #end

  defp payload(payload, "native") do
    splited = Enum.map(payload, &String.split(&1, ":"))
    Enum.all?(splited, &(length(&1) == 2)) || fail("payload should be in form of <key>:<value>")
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
