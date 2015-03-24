defmodule Exd.Builder.Where do
  def build(query, %{where: where_string}, fields_with_types) do
    query_structure = build(where_string, fields_with_types)
    Map.put(query, :wheres, [%Ecto.Query.QueryExpr{expr: query_structure}])
  end

  def build(query, _query_content, _fields_with_types) do
    query
  end

  def build(where_string, fields_with_types) when is_binary(where_string) do
    {:ok, compiled_conditions} = Code.string_to_quoted(where_string)
    {where_clause, _} = Macro.prewalk(compiled_conditions, fields_with_types, &transform/2)
    where_clause
  end

  defp transform({op, field_line, [{field_name, field_line, _}, val]} = _ast, fields_with_types)
   when op in [:'==', :'>', :'<', :'!=', :'>=', :'<='] do
    {_name, type} = List.keyfind(fields_with_types, field_name, 0)
        val = case is_list(val) do
                true -> val |> List.to_string
                _ -> val
              end
    {
      {op, field_line, [{{:'.',[],[{:'&',[],[0]}, field_name]}, [{:ecto_type, type}], []}, val]},
      fields_with_types
    }
  end

  defp transform(other, a) do
    {other, a}
  end
end
