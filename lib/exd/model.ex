defmodule Exd.Model do
  @doc """
  Defines extra layer on ecto models for allowing somewhat configuration-based runtime model extending.
  It allows to define `model`s and `model_add`s.

  ## Example of usage

      import Exd.Model
      model Test do
        schema "test" do
          field :test
        end
      end

  It translates underhood to

      defmodule Test do
        use Ecto.Model
        def name,  do: __schema__(:source)
        schema "test" do
          field :test
        end
        def __source__ do
          {Test,
           [{:schema, meta, ["test", [do: {:field, meta, [:test]}]]}],
           [{:schema, meta, ["test", [do: {:field, meta, [:test]}]]}],
          []}
        end

        def __attribute_option__(_),     do: []
      end
  """
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
      {:schema, _, [_name, [do: block]]} ->
        block
      {:schema, _, [[do: block]]} ->
        block
    end |> unblock
    _actual_schema = {:schema, meta, [name, [do: actual_block]]} = List.keyfind(actual_body, :schema, 0)
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

  @doc """
  model macro defined the module with the name as first argument and second as do body (as a normal
  module). The model macro is replace for ecto models, for the goal to save own source and allow
  dynamic modifications.

  ## Example

      iex> import Exd.Model
      ...> model Test do
      ...>   schema "test" do
      ...>     field :test
      ...>   end
      ...> end
      ...> {Test, actual_body, _, []} = Test.__source__
      ...> [{:schema, _, [schema_name, [do: {:field, _, [:test]}]]}] = actual_body
      ...> schema_name
      "test"

  In __source__ will be saved the model_adds, which were compiled, the original body and the body
  with compiled module_adds.
  """

  defmacro model(module, [do: block]) do
    body = unblock(block)
    gen_model(module, body, body)
  end

  def gen_model(module, body, orig_body, adds \\ []) do
    _schema = {:schema, _meta, [_name, [do: block]]} = List.keyfind(body, :schema, 0)
    all_fields = unblock(block)
    attribute_options = gen_attribute_options(all_fields)
    quote do
      defmodule unquote(module) do
        use Ecto.Model
        def name,  do: __schema__(:source)
        defoverridable [name: 0]
        unquote(body)
        def __source__, do: {unquote(module), unquote(Macro.escape(body)), unquote(Macro.escape(orig_body)), unquote(adds)}
        unquote(attribute_options)
      end
    end
  end

  defp gen_attribute_options(all_fields) do
    field_attributes = Enum.flat_map(all_fields, &extract_attributes(&1))
    attribute_options = for {name, attributes} <- field_attributes do
      quote do
        def __attribute_option__(unquote(name)), do: unquote(attributes)
      end
    end
    quote do
      unquote(attribute_options)
      def __attribute_option__(_), do: []
    end
  end

  defp extract_attributes({:field, _, [name, _, attributes]}),      do: [{name, attributes}]
  defp extract_attributes({:belongs_to, _, [name, _, attributes]}), do: [{belongs_to_name(name, attributes), attributes}]
  defp extract_attributes(_),                                       do: []

  defp belongs_to_name(name, attributes) do
    attributes[:foreign_key] || :"#{name}_id"
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
