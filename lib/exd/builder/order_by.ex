defmodule Exd.Builder.OrderBy do
  def build(query, %{"order_by" => order_by_content}) do
    {field, default_direction} = case String.split(order_by_content, ":") do
                                   [field] ->
                                     {field |> String.to_atom, :asc}
                                   [field, direction] ->
                                     {field |> String.to_atom, direction |> String.to_atom}
                                 end
    Map.put(query, :order_bys, [%{'__struct__': :'Elixir.Ecto.Query.QueryExpr',
                                  expr: [{default_direction,{{:'.',[], [{:'&',[], [0]}, field]}, [], []}}], params: []}])
  end

  def build(query, _query_content), do: query

end
