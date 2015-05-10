defmodule Exd.Escript.Util do

  @doc false
  def print_associations(_, _, nil) do
  end

  @doc false
  def print_associations(model, table_name, association_table) do
    IO.write model
    IO.write " association with: " <> (association_table.__struct__ |> Atom.to_string)
    IO.puts ""
    # get the longest field name for pretty print
    keys = for key <- Map.keys(association_table), do: Atom.to_string(key)
    IO.puts ""
    for key <- Map.keys(association_table) do
      case key do
        ^table_name ->
          :pass
        _ ->
          :io.format(" ~p", [key])
          IO.write String.duplicate(" ", longest_keylength(keys) - (key |> Atom.to_string |> String.length))
          :io.format(" : ~p~n", [Map.get(association_table, key)])
      end
    end
  end

  @doc """
  ## Example

      iex> longest_keylength([:abc, :abcd])
      4

  """
  def longest_keylength([]), do: 0
  def longest_keylength(keys), do: Enum.map(keys, fn(x) -> Atom.to_string(x) |> String.length end) |> Enum.max

  @doc false
  def get_rpc_params(model) do
    {("Elixir." <> model) |> String.to_atom, ("Elixir." <> model <> ".Api") |> String.to_atom}
  end

  @doc false
  def print_associations_helper(assoc_list, model, table_name, data) do
    case assoc_list do
      [] -> :pass
      _ ->
        for assoc <- assoc_list do
          print_associations(model, table_name, Map.get(data, assoc))
        end
    end
  end

  def print_row(data, fields) do
    for field <- fields do
      IO.write "#{field}"
      IO.write String.duplicate(" ", longest_keylength(fields) - (field |> Atom.to_string |> String.length))
      IO.write " : #{Map.get(data, field)}\n"
    end
  end

  @doc false
  def print_rows_without_assoc(_data, _assoc_list, _association_field_name) do
    true
  end

end
