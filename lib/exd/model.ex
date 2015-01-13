defmodule Exd.Model do
  defmacro __using__(_) do
    quote do
      import Exd.Model, only: [model: 2]
    end
  end

  def migrate(repo, module) do
    Exd.Migration.generate(module) |> Code.eval_quoted
    Ecto.Migrator.up(repo, :crypto.rand_uniform(0, 1099511627775), Exd.Migration.migration_module_name(module))
  end

  def compile_migrate_model(repo, module, module_adds) do
 #  compile_model(module, module_adds)
    migrate(repo, module)
  end

 # def compile_model(module, module_adds) do
 #   {^module, name, _actual_body, body, _adds} = module.__source__()
 #   new_body = Enum.reduce(module_adds, body, &(&1.__source__(module) |> merge_model(&2)))
 #   gen_model(module, new_body, body, module_adds) |> Code.eval_quoted
 # end

  defmacro model_add(module_add, [do: block]) do
    block_list = unblock(block)
    quoted = for {:model, _, [name, [do: model_block]]} <- block_list do
      quote do
        def __source__(unquote(name)), do: unquote(model_block |> unblock |> Macro.escape)
      end
    end
    {models, quoted_models} =
      for {:model, _, [name, model_block]} <- block_list do
        module = Macro.expand(name, __ENV__)
        {^module, name, actual_body, body, adds} = module.__source__()
        IO.inspect({name, adds})
        new_body = merge_model(model_block, actual_body)
        {module, gen_model(module, new_body, body, [module_add | adds])}
      end |> :lists.unzip
    quote do
      defmodule unquote(module_add) do
        def __source__, do: {unquote(module_add), unquote(models)}
        unquote_splicing(quoted)
      end
      unquote_splicing(quoted_models)
    end
  end

  defmacro model(module, [do: block]) do
    body = unblock(block)
    gen_model(module, body, body)
  end

  def find_field_attribute(fields, attribute) do
    for {_, _, [name, type, opts]} <- fields, List.keymember?(opts, attribute, 0) == true do
      {name, type, opts}
    end
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
    # Generate new schema
    attribute_options = for {name, attributes} <- field_attributes do
      quote do
        def __attribute_option__(unquote(name)), do: unquote(attributes)
      end
    end

    quote do
      defmodule unquote(module) do
        use Ecto.Model
        @primary_key {unquote(primary_key_field), unquote(primary_key_type), unquote(primary_key_opts)}
        unquote(schema)
        def __source__, do: {unquote(module), unquote(Macro.escape(body)), unquote(Macro.escape(orig_body)), unquote(adds)}
        unquote(attribute_options)
        def __attribute_option__(_), do: []
      end
    end
  end

  defp merge_model([do: adds], model), do: merge_model(unblock(adds), model)
  defp merge_model(adds, [do: block]), do: merge_model(adds, unblock(block))
  defp merge_model([], model), do: model
  defp merge_model([{:object, _, [key, [do: block]]} = object | next], model) do
    objects = [] #Enum.filter(model, &object?(key, &1))
    {exists, add} = case objects do
      [] -> {false, object}
      [{:object, meta, [key]}] -> {true, {:object, meta, [key, [do: block]]}}
      [{:object, meta, [key, rest]}] -> {true, {:object, meta, [key, [do: (unblock(block) |> merge_model(rest))]]}}
    end
    new_model = case exists do
      false -> model ++ [add]
      #true  -> Enum.map(model, &(if object?(key, &1) do add else &1 end))
    end
    merge_model(next, new_model)
  end
  defp merge_model([{k, _, _} = kv | next], model)
   when k in [:field, :belongs_to, :has_many, :has_one] do
    merge_model(next, model ++ [kv])
  end

  defp unblock({:__block__, _, body}), do: body
  defp unblock(body), do: List.wrap(body)
end
