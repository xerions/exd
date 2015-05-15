defmodule Exd.Api do
  import Exd.Util
  @moduledoc ~S"""
  This module defines set of functions for introspection an API, defined on model.

  ## Example of definition

      import Exd.Model
      model Example do
        schema "weather" do
          field :test1
          field :test2
          timestamps
        end
      end
      defmodule Example.Api do
        @moduledoc "Example API documentation"
        @name "Example"
        @tech_name "example"
        use Exd.Api, model: Example, repo: EctoIt.Repo
        crud
      end

  The `Exd.Api` automaticly imports `Exd.Api.Crud.crud/0` macro.

  Any `Exd.Api` will generate some module attributes, which should be overriden, if they differentate
  from model use case.

  * `@exported`  - Defines attributes, which are exported with Api
  * `@required`  - Defines attributes, which are required on creation
  * `@read_only` - Defines attributes, which can be readed, but can't be modified
  * `@model`     - Defined on use model
  * `@repo`      - Defined on use repo

  * `__exd_api__(:model)`     - Returns an model of an API
  * `__exd_api__(:repo)`      - Returns an repo of an model
  * `__exd_api__(:instance)`  - Returns instance of model;
  * `__exd_api__(:exported)`  - Returns all exported attributes
  * `__exd_api__(:read_only)` - Returns only read_only attributes (defaults to `:id` `:inserted_at`, `:updated_at`)
  * `__exd_api__(:required)`  - Returns required for creation attributes
  * `__exd_api__(:optional)`  - Returns optional for creation attributes
  * `__exd_api__(:changable)` - Returns changable for update attributes

  """

  @field_map %{name: nil, type: nil, datatype: nil, description: nil, relation: ""}
  @doc ~S"""
  Doing introspection of an api of a model.

  ## Example

      iex> Exd.Api.introspection(Example.Api)
      %{name: "example",
        desc_name: "Example",
        description: "Example API documentation",
        methods: ["options", "get", "inser", "put", "delete"],
        fields:
         [%{datatype: :integer, description: "", name: :id, relation: "", type: :read_only},
          %{datatype: :string, description: "", name: :test1, relation: "", type: :mandatory},
          %{datatype: :string, description: "", name: :test2, relation: "", type: :mandatory},
          %{datatype: :datetime, description: "", name: :inserted_at, relation: "", type: :read_only},
          %{datatype: :datetime, description: "", name: :updated_at, relation: "", type: :read_only}]}
  """
  def introspection(api) do
    fields    = api.__exd_api__(:exported)
    required  = api.__exd_api__(:required)
    read_only = api.__exd_api__(:read_only)
    model     = api.__exd_api__(:model)
    associations = get_associations(api)
    fields = for field <- fields do
      field_map = %{ @field_map | name: field,
                                  datatype: datatype(api, field),
                                  description: model.__attribute_option__(field)[:desc] || "",
                                  type: mandantory(field, required, read_only) }
      case List.keyfind(associations, field, 0) do
        {_, table, _} -> %{field_map | relation: table}
        nil           -> field_map
      end
    end
    %{name:        Apix.spec(api),
      desc_name:   Apix.spec(api, :name),
      description: Apix.spec(api, :doc),
      methods:     Apix.spec(api, :methods),
      fields:      fields}
  end

  defp datatype(api, field) do
    type = api.__schema__(:field, field)
    if function_exported?(type, :type, 0) do type.type else type end
  end

  defp mandantory(field, required, read_only) do
    case {field in required, field in read_only} do
      {true, false}  -> :mandantory
      {false, true}  -> :read_only
      {false, false} -> :optional
    end
  end

  defp get_associations(module) do
    module.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case module.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_module} ->
          [{field, table_name(assoc_module), assoc_module}]
        _ ->
          []
      end
    end)
  end

  defmacro __using__(opts) do
    model = opts[:model] || raise ArgumentError, message: "Api should have `model` in options"
    repo = opts[:repo] || raise ArgumentError, message: "Api should have `repo` in options"
    quote do
      use Apix
      import Exd.Api, only: :macros
      import Exd.Api.Crud, only: :macros
      @before_compile Exd.Api

      require unquote(model)
      @model unquote(model)
      @repo  unquote(repo)
      @exported @model.__schema__(:fields)
      @read_only [:id, :inserted_at, :updated_at]
      @required @exported -- @read_only

      api "options", :__options__
      @doc """
      Method: `options`.
      Introspection of #{String.downcase(@name)} API.
      """
      def __options__(_args), do: Exd.Api.introspection(__MODULE__)
      defdelegate [__schema__(target), __schema__(target, id)], to: unquote(model)
    end
  end

  defmacro __before_compile__(env) do
    module = env.module
    [required, exported, read_only] = for attr <- [:required, :exported, :read_only], do: Module.get_attribute(module, attr)
    quote bind_quoted: [exported: exported, read_only: read_only, required: required] do
      def __exd_api__(:model),     do: @model
      def __exd_api__(:repo),      do: @repo
      def __exd_api__(:instance),  do: @model.__struct__
      def __exd_api__(:exported),  do: @exported
      def __exd_api__(:read_only), do: @read_only
      def __exd_api__(:required),  do: @required

      @optional  (exported -- read_only) -- required
      @changable (exported -- read_only)
      def __exd_api__(:optional),  do: @optional
      def __exd_api__(:changable), do: @changable
    end
  end
end
