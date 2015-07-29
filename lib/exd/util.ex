defmodule Exd.Util do
  @shortdoc "Exd.Model utils"

  def table_name(model) do
    model.name |> String.to_atom
  end

  def field(value, join_models) do
    {index, field} = case String.split(value, ".") do
      [field] ->
        {0, field}
      [model, field] ->
        index = get_index(join_models, model |> String.to_atom)
        {index, field}
    end
    {index, String.to_atom(field)}
  end

  def get_index(join_models, model) do
    index = Enum.find_index(join_models, &(model == &1))
    case index do
      nil -> 0
      _ -> index + 1
    end
  end

end
