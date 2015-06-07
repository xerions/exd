defmodule Exd.Builder.OrderBy do
  def build(query, %{"order_by" => order_by_content}) do
    [field | next] = String.split(order_by_content, ":")
    direction = case next do
      [] -> :asc
      [direction] -> direction
    end
    query_expr = %Ecto.Query.QueryExpr{expr: [quoted_expr(direction, field |> String.to_atom)]}
    %{query | order_bys: [query_expr], params: []}
  end

  def build(query, _query_content), do: query

  def quoted_expr(direction, field) do
    quote do: {unquote(direction), &0.unquote(field)()}
  end

end
