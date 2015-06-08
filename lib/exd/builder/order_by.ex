defmodule Exd.Builder.OrderBy do
  def build(query, %{"order_by" => order_by_content}, join_models) do
    [field | next] = String.split(order_by_content, ":")
    direction = case next do
      [] -> :asc
      [direction] -> direction |> String.to_atom
    end
    {index, field} = Exd.Util.field(field, join_models)
    query_expr = %Ecto.Query.QueryExpr{expr: [quoted_expr(direction, index, field)], params: []}
    %{query | order_bys: [query_expr]}
  end

  def build(query, _query_content, _), do: query

  def quoted_expr(direction, index, field) do
    {direction, {{:., [], [{:&, [], [index]}, field]}, [], []}}
  end

end
