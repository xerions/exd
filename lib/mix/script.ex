defmodule Mix.Tasks.Compile.Exd.ScriptTemplate do
  import Ecto.Query
  import Mix.Tasks.Compile.Exd.Util
  import Mix.Tasks.Compile.Query.Builder.Where

  @doc """
  exd escript 'update' API.

  Usage
    escript_name node@name MyModel id_number update foo: bar
  """
  def main([node, model, id, "update" | update_content]) do
    node_name = connect(node)
    {query_model, api_module} = get_rpc_params(model)
    {primary_key, fields_with_types} = :rpc.call(node_name, api_module, :__get_fields_with_types__, [query_model])

    case :rpc.call(node_name, ("Elixir." <> model <> ".Api") |> String.to_atom, :get, [id]) do
      {_, _, nil} ->
        IO.puts "Result: not found"
      {_, _, [rows]} ->
        update_fields = Enum.chunk(update_content, 2)
        data_map = Map.from_struct(rows)

        updated_fields = for {key, val} <- data_map, key != :id do
          case Enum.find(update_fields, fn([field, _]) -> field == Atom.to_string(key) end) do
            nil ->
              {key, val}
            [f, v] ->
              {_, type} = Enum.find(fields_with_types, fn({field, _}) -> field == String.to_atom(f) end)
              val = case type do
                      :integer -> String.to_integer v
                      :float   -> String.to_float  v
                      :boolean -> String.to_atom   v
                      _ -> v
                    end
              {key, val}
          end
        end

        updated_fields = case primary_key do
                           :id ->
                             [{:id, Map.get(data_map, primary_key)} | updated_fields]
                           _ ->
                             updated_fields
                         end
        :rpc.call(node_name, api_module, :update, [fill_map_for_insert(%{__struct__: query_model}, updated_fields)])
    end
  end

  @doc """
  exd escript 'delete_all' API.

  Usage:
    escript_name node@name MyModel delete_all
  """
  def main([node, "delete_all", model]) do
    node_name = connect(node)
    {query_model, api_module} = get_rpc_params(model)
    :rpc.call(node_name, api_module, :delete_all, [query_model])
  end

  @doc """
  exd escript 'delete' API.

  Usage:
    escript_name node@name MyModel delete foo where: \"bar > 1\"
  """
  def main([node, "delete", model | argv]) do
    node_name = connect(node)
    {query_model, api_module} = get_rpc_params(model)
    {_, fields_with_types} = :rpc.call(node_name, api_module, :__get_fields_with_types__, [query_model])
    empty_query = from table in query_model
    {_, query_structure} = build_where_clause(argv, fields_with_types)
    formed_query = Map.put(empty_query, :wheres, [%Ecto.Query.QueryExpr{__struct__: :'Elixir.Ecto.Query.QueryExpr', expr: query_structure}])
    case :rpc.call(node_name, api_module, :delete, [formed_query]) do
      :not_found ->
        IO.puts "Row with this primary key not found"
      _ ->
        IO.puts IO.ANSI.bright <> IO.ANSI.green <> "Done." <> IO.ANSI.reset 
    end
  end

  @doc """
  exd escript 'select' API.

  Usage:
    escript_name node@name MyModel select foo where: \"bar > 1\" --limit 2 --offset 4 --distinct bar
  """
  def main([node, "select", model | query_content]) do
    node_name = connect(node)
    {query_model, api_module} = get_rpc_params(model)

    associations = :rpc.call(node_name, api_module, :__associations__, [query_model])
    table_name   = :rpc.call(node_name, api_module, :__tablename__, [query_model])
    # get schema fields and types
    {_primary_key, fields_with_types} = :rpc.call(node_name, api_module, :__get_fields_with_types__, [query_model])
    # Build a query
    empty_query = from table in query_model, preload: ^associations, select: table
    {query, argv} = select_fields_helper(empty_query, query_content)
    {columns, query_structure} = build_where_clause(argv, fields_with_types)
    formed_query = Map.put(query, :wheres, [%Ecto.Query.QueryExpr{__struct__: :'Elixir.Ecto.Query.QueryExpr', expr: query_structure}])
    # Execute query
    query_result = :rpc.call(node_name, api_module, :select, [formed_query])

		case query_result do
			[] ->
				IO.puts "Nothing found."
			_ ->
				# Render output
				for row <- query_result do
					row = remove_struct_field(row)
					data_list = case columns do
												[] -> Map.to_list(row)
												_ ->
													cols = for c <- columns, do: String.to_atom c
													for {n, f} <- Map.to_list(row), Enum.member?(cols, n) == true, do: {n, f}
											end
					IO.puts "--------------------------------------------------------------------------------"
					:io.format("~p: ~n", [query_model])
					# traverse and render data from one row
					for {field_name, _val} <- data_list, do: print_rows_without_assoc(row, associations, field_name)
					IO.puts ""
					print_associations_helper(associations, query_model, table_name, row)
					IO.puts "--------------------------------------------------------------------------------" 
			end
		end
  end

  @doc """
  exd escript 'insert' API.

  Usage:
    escript_name node@name insert MyApp.Model value1 value2 ....
  """
  def main([node, "insert", model | values]) do
    node_name = connect(node)
    #
    # get all fields with types
    #
    {query_model, api_module} = get_rpc_params(model)
    {primary_key, fields_with_types} = :rpc.call(node_name, api_module, :__get_fields_with_types__, [query_model])

    values = case primary_key do
               :id ->
                 if Kernel.length(values) < (Kernel.length(fields_with_types) - 1) do
                   raise model <> " must have " <> ((Kernel.length(fields_with_types) - 1) |> Integer.to_string) <> " fields."
                 end
                 [:id | values]
               _ ->
                 if Kernel.length(values) < Kernel.length(fields_with_types) do
                   raise model <> " must have " <> ((Kernel.length(fields_with_types) - 1) |> Integer.to_string) <> " fields."
                 end
                 values
             end

    # collect data and validate it's data types for inserting query
    formated_fields = for {name, type} <- fields_with_types, name != :id do
      index = Enum.find_index(fields_with_types, fn({x, _}) -> x == name end)
      val = Enum.at(values, index)
      val = case type do
        :integer -> String.to_integer val
        :float   -> String.to_float  val
        :boolean -> String.to_atom   val
        _ -> val
      end
      {name, val}
    end

    formated_fields = case primary_key do
                        :id -> [{:id, nil} | formated_fields]
                          _ -> formated_fields
                      end

    :rpc.call(node_name, api_module, :insert, [fill_map_for_insert(%{__struct__: query_model}, formated_fields)])
  end

  @doc """
  exd escript 'get' API. Prints record from database by given primary key.

  Usage:
    escript_name node@name get MyApp.Model 5
  """
  def main([node, "get", model, id]) do
    node_name = connect(node)
    case :rpc.call(node_name, ("Elixir." <> model <> ".Api") |> String.to_atom, :get, [id]) do
      {_table_name, _assoc_list, nil} ->
        IO.puts "Result: not found"
      {table_name, assoc_list, [rows]} ->
        rows = remove_struct_field(rows)
        IO.puts ""
        for key <- Map.keys(rows), do: print_rows_without_assoc(rows, assoc_list, key)
        IO.puts ""
        print_associations_helper(assoc_list, model, table_name, rows)
    end
  end

  @doc """
  exd 'introspection' API. Prints fields names and types by the given model.

  Usage:
    escript_name node@name show MyApp.MyModel
  """
  def main([node, "show", model]) do
    node_name = connect(node)
    {table_name, fields_str} = :rpc.call(node_name, ("Elixir." <> model <> ".Api") |> String.to_atom, :show, [])
    IO.puts "\nModel - " <> model <> " introspection:\n" <> "Table name: " <> IO.ANSI.bright <> IO.ANSI.green <> table_name <> IO.ANSI.reset <> "\n"
    for field <- fields_str, do: IO.puts field
    IO.puts ""
  end

  def main(_) do
    usage
  end
end


# mix clean && mix compile && mix compile.exd.script exd_charging && ./tposs_charging nonode@nohost select city where "temp_hi = 'a'"
