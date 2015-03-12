defmodule Exd.Model.Util do
  @shortdoc "Exd.Model utils"

  import Atom
  import Enum
  import String
  import Kernel, except: [to_string: 1, length: 1]

  def find_field_attribute(fields, attribute) do
    for {_, _, [name, type, opts]} <- fields, List.keymember?(opts, attribute, 0) == true do
      {name, type, opts}
    end
  end

  def model_to_string(fields) do
    fields_length = for f <- fields do 
			case f do
				{_, _, [field_name, _ | _]} ->
					{length(field_name |> to_string), field_name}
				{_, _, [field_name]} ->
					{length(field_name |> to_string), field_name}
			end
		end

    {max_field_len, _} = max fields_length
    {min_field_len, _} = min fields_length

		title = " | Field" <> spaces(:'| Type', max_field_len + 1) <> "| Type"
    title_len = length(title)

    [" " <> duplicate("-", 76)] ++
    [title  <> duplicate(" ", 76 - title_len) <> "|"] ++
    [" " <> duplicate("-", 76)] ++
    map(fields, 
        fn(field) -> 
          case field do
						{:field, _, [field_name]} ->
							resultStr = " | " <> (field_name |> to_string) <> spaces(field_name, max_field_len) <> 
                          " | " <> "string"
              resultStr <> duplicate(" ", 76 - length(resultStr)) <> "|"

            {:field, _, [field_name, field_type]} ->
              resultStr = " | " <> (field_name |> to_string) <> spaces(field_name, max_field_len) <> 
                          " | " <> (field_type |> to_string)
              resultStr <> duplicate(" ", 76 - length(resultStr)) <> "|"

            {:field, _, [field_name, field_type, _]} ->
              resultStr = " | " <> (field_name |> to_string) <> spaces(field_name, max_field_len) <> 
                          " | " <> (field_type |> to_string)
              resultStr <> duplicate(" ", 76 - length(resultStr)) <> "|"

            {_, _, [field_name, {_, _, belongs_to_mod}]} ->
              resultStr = " | " <> (field_name |> to_string) <> spaces(field_name, max_field_len) <> 
                          " | " <> (Module.concat(belongs_to_mod) |> to_string)
              resultStr <> duplicate(" ", 76 - length(resultStr)) <> "|"
          end
        end)
    ++ [" " <> duplicate("-", 76)]
  end

  def spaces(field_name, max_field_len) do
    field_name_len = field_name |> to_string |> length
    additional_spaces = max_field_len - field_name_len
    duplicate(" ", max_field_len + additional_spaces)
  end

  def extend_module_name(model, str) do
    ((model |> to_string) <> str) |> to_atom
  end

  def table_name(model) do
    model.__schema__(:source) |> to_atom
  end
end
