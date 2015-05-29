defmodule Exd.Builder.Select do
  def build(query, %{"select" => select_string}, join_models) do
    ast = Enum.map(select_string, fn(value_for_select) ->
      case String.split(value_for_select, ".") do
        [field] ->
          ast(field, 0)
        [model, field] ->
          case join_models do
            [] ->
              ast(field, 0)
            _ ->
              join_models = Enum.map(join_models, fn(m) -> String.to_atom(m) end)
              index = Exd.Util.get_index(join_models, model |> String.to_atom)
              ast(field, index)
          end
      end
    end)
    Map.put(query, :select, %Ecto.Query.SelectExpr{expr: {:'%{}', [], ast}})
  end

  def build(query, _, _), do: query

  defp ast(field, index), do: {field |> String.to_atom,{{:'.',[],[{:'&',[],[index]}, field |> String.to_atom]},[],[]}}
end
