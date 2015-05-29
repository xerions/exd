defmodule Exd.Builder.Join do
 
  @default_join :inner
 
  def build(query, %{"left_join" => join_arr}) do
    build(query, :left, join_arr)
  end
 
  def build(query, %{"right_join" => join_arr}) do
    build(query, :right, join_arr)
  end
 
  def build(query, %{"full_join" => join_arr}) do
    build(query, :full, join_arr)
  end
 
  def build(query, %{"join" => join_arr}) do
    build(query, :inner, join_arr)
  end
 
  def build(query, direction, join_arr) do
    join_arr = Enum.map(join_arr, fn(join_model) ->
      %{'__struct__': :'Elixir.Ecto.Query.JoinExpr',
        assoc: nil,
        ix: nil,
        on: %{'__struct__': :'Elixir.Ecto.Query.QueryExpr',
              expr: :true,
              params: []
             },
        qual: direction,
        source: {join_model, nil}
       }
    end)
    Map.put(query, :joins, join_arr)
  end
 
  def build(query, _) do
    query
  end
 
end
