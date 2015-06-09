defmodule Exd.Builder.Select do
  def build(query, %{"select" => select_string}, join_models) do
    ast = Enum.map(select_string, fn(value_for_select) ->
      {index, field} = Exd.Util.field(value_for_select, join_models)
      ast(field, index)
    end)
    Map.put(query, :select, %Ecto.Query.SelectExpr{expr: {:'%{}', [], ast}})
  end

  def build(query, _, _), do: query

  defp ast(field, index), do: {field, {{:'.',[],[{:'&',[], [index]}, field]},[],[]}}
end
