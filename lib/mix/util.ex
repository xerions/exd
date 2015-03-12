defmodule Mix.Tasks.Compile.Exd.Util do

  @doc false
  def usage do
    app = :escript.script_name |> :filename.basename |> List.to_atom
    IO.puts """
        #{app} usage:

        #{app} node@name show model_name - prints model fields/types
        #{app} node@name get MyApp.Model 5 - prints record by given id
        #{app} node@name insert MyApp.Model value1 value2 - insert values to the model
        #{app} node@name select MyApp.Model foo where: \"bar > 1\" --limit 2 --offset 4 --distinct bar
        #{app} node@name delete MyApp.Model where: \"primary_key_field == 1\"
        #{app} node@name delete_all MyApp.Model
        #{app} node@name update MyApp.Model primary_key_val field1 val1 field2 val2 
    """
  end

  @doc false
  def connect(node) do
    {_app, node_name} = get_app_and_node(node)
    :net_kernel.start([:exd_script, :shortnames])
    :net_kernel.connect_node(node_name)
    node_name
  end

  @doc false
  def get_app_and_node(node) do
    {:escript.script_name |> :filename.basename |> List.to_atom, 
     node |> String.to_atom}
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
    longest_key = get_the_longest_key(keys)
    IO.puts ""
    for key <- Map.keys(association_table) do
      case key do
        ^table_name ->
          :pass
        _ ->
          :io.format(" ~p", [key])
          IO.write String.duplicate(" ", longest_key - (key |> Atom.to_string |> String.length))
          :io.format(" : ~p~n", [Map.get(association_table, key)])
      end
    end
  end

  @doc false
  def get_the_longest_key([key | keys]) do
    get_the_longest_key(key, keys, 0)
  end

  def get_the_longest_key(_, [], length) do
    length
  end

  def get_the_longest_key(key, [k | keys], length) do
    case String.length(key) > length do
      true ->
        get_the_longest_key(k, keys, String.length(key))
      false ->
        get_the_longest_key(k, keys, length)
    end
  end

  @doc false
  def get_key_from_cmd(query_structure, index, list, query_field, type) do
    case index do
      nil ->
        {query_structure, list}
      _ ->
        tmp = case type do
          :integer ->
            Enum.at(list, index + 1) |> String.to_integer
          :string ->
            Enum.at(list, index + 1)
        end
        # delete key and value
        list = List.delete_at(list, index)
        list = List.delete_at(list, index)
        {Map.put(query_structure, query_field, %Ecto.Query.QueryExpr{__struct__: :'Ecto.Query.QueryExpr', expr: tmp}), list}
    end
  end

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

  @doc false
  def get_longest_key_helper(data) do
    keys = for key <- Map.keys(data), do: Atom.to_string(key)
    get_the_longest_key(keys)
  end

  @doc false
  def print_rows_without_assoc(data, assoc_list, association_field_name) do
      case Enum.member?(assoc_list, association_field_name) do
        true -> :pass
        _ ->
          longest_key = get_longest_key_helper(data)
          :io.format(" ~p", [association_field_name])
          IO.write String.duplicate(" ", longest_key - (association_field_name |> Atom.to_string |> String.length))
          :io.format(" : ~p~n", [Map.get(data, association_field_name)])
      end
  end

  @doc false
  def select_fields_helper(empty_query, query_content) do
    # limit
    limit_cmd_index = Enum.find_index(query_content, fn(elem) -> elem == "--limit" end)
    {query1, tmp_argv} = get_key_from_cmd(empty_query, limit_cmd_index, query_content, :limit, :integer)
    # distinct
    distinct_cmd_index = Enum.find_index(tmp_argv, fn(elem) -> elem == "--distinct" end)
    {query2, tmp_argv2} = get_key_from_cmd(query1, distinct_cmd_index, tmp_argv, :distincts, :string)
    # offset
    offset_cmd_index = Enum.find_index(tmp_argv2, fn(elem) -> elem == "--offset" end)
    get_key_from_cmd(query2, offset_cmd_index, tmp_argv2, :offset, :integer)
  end

  @doc false
  def fill_map_for_insert(map, []) do
    map
  end

  def fill_map_for_insert(map, [{name, value} | rest]) do
    fill_map_for_insert(Map.put_new(map, name, value), rest)
  end

end
