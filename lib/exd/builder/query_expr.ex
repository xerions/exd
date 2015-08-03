defmodule Exd.Builder.QueryExpr do
  @supported_expr [limit: :integer, distinct: :string, offset: :integer]

  def build(query, query_content) do
    Enum.reduce(@supported_expr, query, &build_expr(&2, query_content, &1))
  end

  @doc false
  def build_expr(query, query_content, {query_field, type}) do
    case query_content[to_string(query_field)] do
      nil ->
        query
      value ->
        Map.put(query, query_field, %Ecto.Query.QueryExpr{expr: cast(value, type)})
    end
  end

  def cast(value, :integer) when is_integer(value), do: value
  def cast(value, :integer), do: String.to_integer(value)
  def cast(value, :string), do: value
end
