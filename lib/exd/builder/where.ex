defmodule Exd.Builder.Where do

  def build(query, %{"where" => where_string}, join_models, fields_with_types) do
    query_structure = build(where_string, join_models, fields_with_types)
    Map.put(query, :wheres, [%Ecto.Query.QueryExpr{expr: query_structure}])
  end

  def build(query, _query_content, _join_models, _fields_with_types), do: query

  def build(where_string, join_models, fields_with_types) when is_binary(where_string) do
    {:ok, compiled_conditions} = Code.string_to_quoted(where_string)
    {where_clause, _} = transform(compiled_conditions, join_models, fields_with_types)
    where_clause
  end

  defp transform({op, _field_line, ast}, join_models, fields_with_types)
  when op in [:'not', :'or', :'and', :'==', :'>', :'<', :'!=', :'>=', :'<='] do
    {
        {op, [], build_ast(ast, join_models, fields_with_types)},
        fields_with_types
    }
  end

  defp transform(expression, join_models, fields_with_types), do: {expression, join_models, fields_with_types}

  defp build_ast([branch | ast], join_models, fields_with_types), do: build_ast([branch | ast], join_models, fields_with_types, [])
  defp build_ast([], _join_models, _fields_with_types, new_ast), do: new_ast
  defp build_ast([branch | ast], join_models, fields_with_types, new_ast) do
    case branch do
      {op, line, tmp_ast} when op in [:'not', :'or', :'and', :'==', :'>', :'<', :'!=', :'>=', :'<='] ->
        internal_ast = build_ast(tmp_ast, join_models, fields_with_types, [])
        build_ast(ast, join_models, fields_with_types, [{op, line, internal_ast} | List.wrap(new_ast)])
      {{:'.', line, [{model, line, nil}, field]}, line, _val} ->
        join_models = Enum.map(join_models, fn(m) -> String.to_atom(m) end)
        index = Exd.Util.get_index(join_models, model)
        {val, ast} = get_val(ast)
        build_ast(ast, join_models, fields_with_types, [[{{:'.', [], [{:'&', [], [index]}, field]}, [], []}, val] | new_ast] |> :lists.flatten)
      {field, line, nil} ->
        type = fields_with_types[field]
        {val, ast} = get_val(ast)
        new_ast = [[{{:'.', line,[{:'&', [], [0]}, field]}, [{:ecto_type, type}], []}, val] | new_ast] |> :lists.flatten
        build_ast(ast, join_models, fields_with_types, new_ast)
      _wrong ->
        raise "Error wrong 'where' clause"
    end
  end

  defp get_val([]), do: {[], []}
  defp get_val([branch | ast]) when is_binary(branch) or is_number(branch) do
    {branch, ast}
  end
end
