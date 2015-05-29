defmodule Exd.Builder.Where do
  def build(query, %{"where" => where_string}, join_models, fields_with_types) do
    query_structure = build(where_string, join_models, fields_with_types)
    Map.put(query, :wheres, [%Ecto.Query.QueryExpr{expr: query_structure}])
  end

  def build(query, _query_content, _join_models, _fields_with_types) do
    query
  end

  def build(where_string, join_models, fields_with_types) when is_binary(where_string) do
    {:ok, compiled_conditions} = Code.string_to_quoted(where_string)
    {where_clause, _} = transform(compiled_conditions, join_models, fields_with_types) 
    where_clause
  end

  defp transform({op, field_line, ast}, join_models, fields_with_types)
  when op in [:'==', :'>', :'<', :'!=', :'>=', :'<='] do
    {
        {op, [], build_ast(ast, join_models, fields_with_types)},
        fields_with_types
    }
  end

  defp transform(expression, join_models, fields_with_types) do
    {expression, join_models, fields_with_types}
  end

  defp build_ast([branch | ast], join_models, fields_with_types) do
    build_ast([branch | ast], join_models, fields_with_types, [])
  end

  defp build_ast([], _join_models, _fields_with_types, ast) do
    ast
  end

  defp build_ast([branch | ast], join_models, fields_with_types, new_ast) do
    case branch do
      {{:'.', line, [{model, line, nil}, field]}, line, val} ->
        index = get_index(join_models, model)
        build_ast(ast, join_models, fields_with_types, [{{:'.', [], [{:'&', [], [index]}, field]}, [], val} | new_ast])
      {field, line, nil} ->
        type = get_type(field, fields_with_types)
        build_ast(ast, join_models, fields_with_types, [{{:'.', line,[{:'&', [], [0]}, field]}, [{:ecto_type, type}],[]} | new_ast])
      val when is_number(val) or is_binary(val) ->
        build_ast(ast, join_models, fields_with_types, [val | new_ast])
      wrong ->
        raise "Error wrong 'where' caluse"
    end
  end

  defp get_index(join_models, model) do
    Enum.find_index(
      Enum.map(join_models, fn(m) -> String.to_atom(m) end),
      fn(m) ->
        model == m
      end)
  end

  defp get_type(field, fields_with_types) do
    {_, type} = List.keyfind(fields_with_types, field, 0)
    type
  end

end
