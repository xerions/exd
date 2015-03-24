import Ecto.Query
import Exd.Util

defmodule Exd.Model do
  defmacro __using__(_) do
    quote do
      import Exd.Model, only: [model: 2]
    end
  end

  def compile_migrate(repo, module, module_adds) do
    compile(module, module_adds)
    Ecto.Migration.Auto.migrate(repo, module)
  end

  def compile(module, module_adds \\ []) do
    {^module, _actual_body, body, _adds} = module.__source__()
    new_body = Enum.reduce(module_adds, body, &(&1.__source__() |> merge_model_add(&2)))
    gen_model(module, new_body, body, module_adds) |> Code.eval_quoted
  end

  defp merge_model_add(add_body, actual_body) do
    add_body = unblock(add_body)
    new_schema_block = case List.keyfind(add_body, :schema, 0) do
      {:schema, _, [name, [do: block]]} ->
        block
      {:schema, _, [[do: block]]} ->
        block
    end |> unblock
    actual_schema = {:schema, meta, [name, [do: actual_block]]} = List.keyfind(actual_body, :schema, 0)
    new_schema = {:schema, meta, [name, [do: merge_schema(new_schema_block, unblock(actual_block))]]}
    List.keyreplace(actual_body, :schema, 0, new_schema) ++ List.keydelete(add_body, :schema, 0)
  end

  defmacro model_add(module_add, [to: module], [do: add_body]) do
    module = Macro.expand(module, __ENV__)
    {^module, actual_body, body, adds} = module.__source__()
    new_body = merge_model_add(add_body, actual_body)
    quoted_model = gen_model(module, new_body, body, [module_add | adds])
    quote do
      defmodule unquote(module_add) do
        def __source__(), do: unquote(add_body |> unblock |> Macro.escape)
      end
      unquote(quoted_model)
    end
  end

  defmacro model(module, [do: block]) do
    body = unblock(block)
    gen_model(module, body, body)
  end

  def gen_model(module, body, orig_body, adds \\ []) do
    schema = {:schema, meta, [name, [do: block]]} = List.keyfind(body, :schema, 0)
    all_fields = unblock(block)

    {primary_key_field, primary_key_type, primary_key_opts} = case find_field_attribute(all_fields, :primary_key) do
      [] ->
        {:id, :integer, []}
      [{field, type, opts}] ->
        {field, type, Keyword.delete(opts, :primary_key)}
    end

    fields = Enum.filter(all_fields, fn({:field, _, [key | _]}) when key == primary_key_field ->
                                         false
                                       (_) ->
                                         true
                                     end)
    field_attributes = for {:field, _, [name, _, attributes]} <- all_fields, do: {name, attributes}
    attribute_options = for {name, attributes} <- field_attributes do
      quote do
        def __attribute_option__(unquote(name)), do: unquote(attributes)
      end
    end

    quote do
      defmodule unquote(module) do
        use Ecto.Model
        @primary_key {unquote(primary_key_field), unquote(primary_key_type), unquote(primary_key_opts)}
        unquote(body)
        def __source__, do: {unquote(module), unquote(Macro.escape(body)), unquote(Macro.escape(orig_body)), unquote(adds)}
        unquote(attribute_options)
        def __attribute_option__(_), do: []
      end
    end
  end

  defp merge_schema([do: adds], model), do: merge_schema(unblock(adds), model)
  defp merge_schema(adds, [do: block]), do: merge_schema(adds, unblock(block))
  defp merge_schema([], model), do: model
  defp merge_schema([kv | next], model) do
    merge_schema(next, model ++ [kv])
  end

  defp unblock({:__block__, _, body}), do: body
  defp unblock(body), do: List.wrap(body)
end
