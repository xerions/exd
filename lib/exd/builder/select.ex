defmodule Exd.Builder.Select do

  @aggr_funs ["count", "avg", "sum", "min", "max"]
  def funs(api, params) do
    keys = Map.keys(params)
    Enum.map(keys, fn(k) ->
      case k in @aggr_funs do
        true -> {k, Map.fetch!(params, k)}
        false -> []
      end
    end) |> :lists.flatten
  end

  def build(query, %{"select" => select_string}, join_models, funs) do
    select_string = add_funs(select_string, funs)
    ast = Enum.map(select_string, fn(value_for_select) ->
      case value_for_select do
        {fun, arg} ->
          {index, field} = Exd.Util.field(arg, join_models)
          {generate_key(fun |> String.to_atom, index, join_models), fn_ast(fun |> String.to_atom, field, index)}
        _ ->
          {index, field} = Exd.Util.field(value_for_select, join_models)
          {generate_key(field, index, join_models), field_ast(field, index)}
      end
    end)
    Map.put(query, :select, %Ecto.Query.SelectExpr{expr: {:'%{}', [], ast}})
  end

  def build(query, _, _, []), do: query
  def build(query, select, join_models, funs) do
    build(query, Map.put_new(%{}, "select", []), join_models, funs)
  end
  def build(query, _, _), do: query

  defp field_ast(field, index), do: {{:'.', [],[{:'&',[], [index]}, field]},[],[]}
  defp fn_ast(meta, field, index), do: {meta, [], [{{:'.',[],[{:'&',[],[0]}, field]},[],[]}]}

  defp generate_key(field, 0, _), do: field
  defp generate_key(field, index, join_models), do: "#{Enum.at(join_models, index - 1)}.#{field}"

  defp add_funs([], []), do: []
  defp add_funs(str, funs), do: str ++ funs

end
