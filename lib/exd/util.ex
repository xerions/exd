defmodule Exd.Util do
  @shortdoc "Exd.Model utils"

  def table_name(model) do
    model.__schema__(:source) |> Kernel.to_atom
  end

  def get_index(join_models, model) do
    index = Enum.find_index(join_models, &(model == &1))
    case index do
      nil -> 0
      _ -> index + 1
    end
  end

end
