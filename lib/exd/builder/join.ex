defmodule Exd.Builder.Join do

  @default_join :inner
  @join_direction  ["left_join", "right_join", "full_join", "join"]
  @mapping  [left: "left_join", right: "right_join", full_join: "full_join", inner: "join"]

  def models(params) do
    keys = Map.keys(params)
    Enum.filter_map(keys, fn(k) ->
      k in @join_direction
    end, &(&1)) |> models_list(params)
  end

  defp models_list([], _params) do
    []
  end

  defp models_list([key], params) do
    Map.get(params, key)
  end

  for {inner, extern} <- @mapping do
    def build(query, %{unquote(extern) => join_arr}), do: build(query, unquote(inner), join_arr)
  end

  def build(query, _) do
    query
  end

  def build(query, direction, join_arr) do
    join_arr = Enum.map(join_arr, fn(join_model) ->
      %Ecto.Query.JoinExpr{
        on: %Ecto.Query.QueryExpr{expr: :true, params: []},
        qual: direction,
        source: {join_model, nil}
       }
    end)
    Map.put(query, :joins, join_arr)
  end

end
