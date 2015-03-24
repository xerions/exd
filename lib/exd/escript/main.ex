defmodule Exd.Escript.Main do
  import Exd.Escript.Util

  @doc """
  exd escript 'update' API.

  Usage
    escript_name node@name MyModel id_number update foo: bar
  """
  def main([]) do
    script = script
    IO.puts """
#{script} usage:

  #{script} node@host - connects to nodes and print available models

"""
  end

  def main([node | args]) do
    escript_module = String.to_atom(Atom.to_string(script) <> "_escript")
    escript_module.start_app(:exd)
    on_connect(node, args)
  end

  def on_connect(node, args) do
    node = connect(node) || fail("failed to connect to #{node}")
    {:ok, modules} = rpc(node, :application.get_key(script, :modules))
    modules = Enum.filter modules, fn(module) ->
      if to_string(module) =~ ~r/.*\.Api$/ do
        rpc(node, module.__info__(:functions))[:introspection]
      end
    end
    model_list = for module <- modules, into: %{}, do: {rpc(node, module.__schema__(:source)), module}
    case args do
      []      ->
        print_all_models(node, model_list)
      [model | next_args] ->
        module = model_list[model] || fail("model #{model} is unknown")
        main(node, model, module, next_args)
    end
  end

  defp main(node, model, api, []) do
    script = script
    {introspection, actions} = rpc(node, api.introspection())

    introspection_string = Exd.Util.model_to_string(introspection) |> Enum.join("\n")
    IO.puts """
#{script} #{node} #{model}

#{introspection_string}

Available actions: #{Enum.join(actions, ", ")}
"""
  end

  defp main(node, model, api, [action | values]), do: main(node, model, api, action, values)

  defp main(node, _model, api, "insert", values) do
    fields = rpc(node, api.__schema__(:fields))
    formated_fields = Enum.zip(fields, values)
    rpc(node, api.insert(formated_fields)) |> change_result
  end

  defp main(node, _model, api, "get", [id]) do
    fields = rpc(node, api.__schema__(:fields))
    on_get(node, api, id, fn(row) -> print_row(row, fields) end)
  end

  defp main(node, _model, api, "update", [id | update_content]) do
    on_get(node, api, id, fn(row) ->
      update_fields = Enum.chunk(update_content, 2) |> Enum.map(&List.to_tuple/1)
      rpc(node, api.update(row, update_fields)) |> change_result
    end)
  end

  defp main(node, _model, api, "delete", [id]) do
    on_get(node, api, id, fn(row) ->
      rpc(node, api.delete(row)) |> change_result
    end)
  end

  defp main(node, _model, api, "delete_all", []) do
    rpc(node, api.delete_all())
  end

  defp main(node, _model, api, "list", []) do
    select(node, api, %{})
  end

  defp main(node, _model, api, "select", query_content) do
    query_content = Enum.chunk(query_content, 2) |> Enum.map(fn([type, value]) -> {String.to_atom(type), value} end) |> Enum.into(%{})
    select(node, api, query_content)
  end

  defp main(node, _, api, "subscribe", ["where" | subscription_info]) do
    sub_info = Enum.reduce(subscription_info, "", fn(info, acc) -> info <> " " <> acc <> " " end) |> String.rstrip
    rpc(node, api.subscribe(sub_info, [adapter: Ecto.Subscribe.Adapter.Remote, receiver: node()])) |> IO.inspect
    :timer.sleep(:infinity)
  end

  defp select(node, api, query_content) do
    case rpc(node, api.select_on(query_content)) do
      [] ->
        IO.puts "Nothing found"
      query_result ->
        fields = rpc(node, api.__schema__(:fields))
        String.duplicate("-", 80) |> IO.puts
        for row <- query_result, do: print_row(row, fields)
        String.duplicate("-", 80) |> IO.puts
    end
  end

  defp change_result({:badrpc, error}), do: IO.inspect(error)
  defp change_result({:error, errors}), do: IO.inspect(errors)
  defp change_result(model), do: IO.puts("id: #{model.id}")

  defp on_get(node, api, id, fun) do
    case rpc(node, api.get(id)) do
      nil ->
        IO.puts "Result: #{id} not found"
      [row] ->
        fun.(row)
    end
  end

  def print_all_models(node, model_list) do
    script = script
    IO.puts """
#{script} #{node}:

available models: #{Enum.map(model_list, &elem(&1, 0)) |> Enum.join(" ")}

introspection of a model: #{script} #{node} <model>
"""
  end
end
