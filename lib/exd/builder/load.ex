defmodule Exd.Builder.Load do
  def build(query = %{from: {_, model}}, query_content) do
    Map.put(query, :preloads, preload(query_content, model))
  end

  def preload(%{"load" => list}, model) when is_list(list) do
    model.__schema__(:associations)
    |> Stream.map(&Atom.to_string/1)
    |> Stream.filter(&(&1 in list))
    |> Enum.map(&String.to_atom/1)
  end
  def preload(_, model), do: []
end
