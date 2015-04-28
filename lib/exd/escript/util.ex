defmodule Exd.Escript.Util do

  @doc false
  def script do
    case :escript.script_name do
      '--no-halt' -> Process.get(:__script__)
      script -> script |> Path.basename |> String.to_atom
    end
  end

  def usage do
    app = script
    IO.puts """
#{app} usage:

  #{app} node@host - connects
    #{app} node@name show model_name - prints model fields/types
    #{app} node@name insert MyApp.Model value1 value2 - insert values to the model
    #{app} node@name select MyApp.Model foo where: \"bar > 1\" --limit 2 --offset 4 --distinct bar
    #{app} node@name delete MyApp.Model where: \"primary_key_field == 1\"
    #{app} node@name delete_all MyApp.Model
    #{app} node@name update MyApp.Model primary_key_val field1 val1 field2 val2
    """
  end

  @doc false
  def connect(node) do
    node_name = node |> String.to_atom
    digit = case System.cmd("epmd", ["-names"]) |> elem(0) |> String.split("\n") |> Enum.flat_map(&name(&1)) do
      [] -> 0
      digits -> Enum.max(digits)
    end
    :net_kernel.start([String.to_atom("exd_script#{digit + 1}"), :shortnames])
    case :net_kernel.connect_node(node_name) do
      true  -> node_name
      false -> nil
    end
  end

  defp name(line) do
    case String.split(line) do
      ["name", "exd_script" <> digit | _] -> [String.to_integer(digit)]
      _ -> []
    end
  end

  def fail(message) do
    IO.puts(message)
    #:erlang.halt(1)
  end

  defmacro rpc(node, {{:., _, [module, function]}, _, args}) do
    quote do
      :rpc.call(unquote(node), Exd.Escript.Util, :relay, [unquote(module), unquote(function), unquote(args)])
    end
  end

  def relay(module, function, args) do
    :erlang.group_leader(Process.whereis(:user), self)
    apply(module, function, args)
  end

  @doc false
  def get_app_and_node(node) do
    {:escript.script_name |> :filename.basename |> List.to_atom,
     }
  end

  @doc false
  def remove_struct_field(struct) do
    Map.delete(struct, :__struct__) |> Map.delete(:__state__)
  end

  @doc false
  def print_associations(_, _, nil) do
  end

  @doc false
  def print_associations(model, table_name, association_table) do
    IO.write model
    IO.write " association with: " <> (association_table.__struct__ |> Atom.to_string)
    IO.puts ""
    association_table = remove_struct_field(association_table)
    # get the longest field name for pretty print
    keys = for key <- Map.keys(association_table), do: Atom.to_string(key)
    IO.puts ""
    for key <- Map.keys(association_table) do
      case key do
        ^table_name ->
          :pass
        _ ->
          :io.format(" ~p", [key])
          IO.write String.duplicate(" ", longest_keylength(keys) - (key |> Atom.to_string |> String.length))
          :io.format(" : ~p~n", [Map.get(association_table, key)])
      end
    end
  end

  @doc """
  ## Example

      iex> longest_keylength([:abc, :abcd])
      4

  """
  def longest_keylength([]), do: 0
  def longest_keylength(keys), do: Enum.map(keys, fn(x) -> Atom.to_string(x) |> String.length end) |> Enum.max

  @doc false
  def get_rpc_params(model) do
    {("Elixir." <> model) |> String.to_atom, ("Elixir." <> model <> ".Api") |> String.to_atom}
  end

  @doc false
  def print_associations_helper(assoc_list, model, table_name, data) do
    case assoc_list do
      [] -> :pass
      _ ->
        for assoc <- assoc_list do
          print_associations(model, table_name, Map.get(data, assoc))
        end
    end
  end

  def print_row(data, fields) do
    for field <- fields do
      IO.write "#{field}"
      IO.write String.duplicate(" ", longest_keylength(fields) - (field |> Atom.to_string |> String.length))
      IO.write " : #{Map.get(data, field)}\n"
    end
  end

  @doc false
  def print_rows_without_assoc(data, assoc_list, association_field_name) do
    true
  end

end