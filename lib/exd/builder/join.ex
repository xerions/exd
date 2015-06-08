defmodule Exd.Builder.Join do

  @default_join :inner
  @join_direction  ["left_join", "right_join", "full_join", "join"]
  @mapping  [left: "left_join", right: "right_join", full_join: "full_join", inner: "join"]

  def models(api, params) do
    keys = Map.keys(params)
    Enum.filter_map(keys, fn(k) ->
      k in @join_direction
    end, &(&1)) |> models_list(api, params)
  end

  defp models_list([], _api, _params) do
    []
  end

  defp models_list([key], api, params) do
    associations = api.__schema__(:associations) |> Enum.map(&Atom.to_string(&1))
    Map.get(params, key) |> Stream.filter(&(&1 in associations)) |> Enum.map(&String.to_atom/1)
  end

  for {inner, extern} <- @mapping do
    def build(query, %{unquote(extern) => _}, join_models), do: do_build(query, unquote(inner), join_models)
  end

  def build(query, _, _) do
    query
  end

  defp do_build(query, direction, join_arr) do
    join_arr = Enum.map(join_arr, fn(join_model) ->
      %Ecto.Query.JoinExpr{
        assoc: {0, join_model},
        on: %Ecto.Query.QueryExpr{expr: :true, params: []},
        qual: direction
       }
    end)
    Map.put(query, :joins, join_arr)
  end

end
