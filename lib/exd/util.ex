defmodule Exd.Util do
  @shortdoc "Exd.Model utils"

  import Enum
  import String
  import Kernel, except: [length: 1]

  def find_field_attribute(fields, attribute) do
    for {_, _, [name, type, opts]} <- fields, List.keymember?(opts, attribute, 0) == true do
      {name, type, opts}
    end
  end

  def get_associations(module) do
    module.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case module.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_module} ->
          [{field, table_name(assoc_module), assoc_module}]
        _ ->
          []
      end
    end)
  end

  def model_to_string(fields) do
    fields_length = for {field_name, _, _} <- fields, do:	{length(field_name |> to_string), field_name}

    {max_field_len, _} = max fields_length
    {min_field_len, _} = min fields_length

		title = " | Field" <> spaces(:'| Type', max_field_len + 1) <> "| Type"
    title_len = length(title)

    [" " <> duplicate("-", 76)] ++
    [title  <> duplicate(" ", 76 - title_len) <> "|"] ++
    [" " <> duplicate("-", 76)] ++
    map(fields, fn({field_name, field_type, belongs_to}) ->
      resultStr = " | " <> (field_name |> to_string) <> spaces(field_name, max_field_len) <>
                  " | " <> (field_type |> to_string) <> " | " <> (belongs_to |> to_string)
      resultStr <> duplicate(" ", 76 - length(resultStr)) <> "|"
    end) ++ [" " <> duplicate("-", 76)]
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
