defmodule Mix.Tasks.Compile.Query.Builder.Where do

  def build_where_clause(args, fields_with_types) do
    fields_to_select = Enum.take_while(args, fn(arg) -> arg != "where" end)
    fields_to_select_count = length(fields_to_select)
		# get all after where
    {_, fields_after_where} = Enum.split(args, fields_to_select_count + 1)
    where_string = Enum.join(fields_after_where, " ")
		# compile where clause
    {:ok, compiled_conditions} = Code.string_to_quoted(where_string)
		# return set of fields which need to select and 'where' clause
		{where_clause, _} = Macro.prewalk(compiled_conditions, fields_with_types, &transform/2)
		{fields_to_select, where_clause}
  end

	def build_where_clause_from_string(where_string, fields_with_types) do
		{:ok, compiled_conditions} = Code.string_to_quoted(where_string)
		{where_clause, _} = Macro.prewalk(compiled_conditions, fields_with_types, &transform/2)
		where_clause
	end


	defp transform({op, field_line, [{field_name, field_line, _}, val]} = _ast, fields_with_types) 
	  when op in [:'==', :'>', :'<', :'!=', :'>=', :'<='] do
		{_name, type} = List.keyfind(fields_with_types, field_name, 0)

		val = case is_list(val) do
						true -> val |> List.to_string
						_ -> val
					end
    {
				{op, field_line, [{{:'.',[],[{:'&',[],[0]}, field_name]}, [{:ecto_type, type}], []}, val]},
				fields_with_types
		}
  end
	
  defp transform(other, a) do
    {other, a}
  end

end
