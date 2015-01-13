defmodule Exd.Migration do
  def generate(model) do
    table_name = table_name(model)
    module_name = migration_module_name(model)
    primary_key = model.__schema__(:primary_key)
    key? = primary_key == :id
    assocs = model.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case model.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_model} ->
          [{field, table_name(assoc_model)}]
        _ ->
          []
      end
    end)

    add_fields = for name <- model.__schema__(:fields), name != :id do
      case assocs[name] do
        nil ->
          type = model.__schema__(:field, name)
          opts = model.__attribute_option__(name)
          quote do: add(unquote(name), unquote(type), unquote(opts))
        table ->
          quote do: add(unquote(name), Ecto.Migration.references(unquote(table)))
      end
    end

    # generate new module
    quote do
      defmodule unquote(module_name) do
        use Ecto.Migration
        def up do
          create table(unquote(table_name), primary_key: unquote(key?)) do
            unquote(add_fields)
          end
        end
        def down do
          drop table(unquote table_name)
        end
      end
    end
  end

  def migration_module_name(model) do
    (model |> Atom.to_string) <> ".Migration" |> String.to_atom
  end

  defp table_name(model) do
    model.__schema__(:source) |> String.to_atom
  end
end
