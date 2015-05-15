defmodule Exd.Api.Crud do
  @moduledoc """
  Generic implementation of get/insert/update/delete for APIs. Note, that `Exd.Api` automaticly
  import `Exd.Api.Crud` in a scope, that you can define crud directly.

  ## Example of definition

      import Exd.Model
      model Example do
        field :test1
        field :test2
      end
      defmodule Example.Api do
        @moduledoc "Example module documentation"
        @name "Example"
        @tech_name "example"
        use Exd.Model.Api
        crud
      end

  ## Crud apis

  For more selective api definition, it is possible to add option `:only`.

      defmodule Example.Api do
        @moduledoc "Example module documentation"
        @name "Example"
        @tech_name "example"
        use Exd.Model.Api
        crud, only: [:insert, :get]
      end
  """
  import Ecto.Query

  defmacrop repo(api) do
    quote do: unquote(api).__exd_api__(:repo)
  end
  defmacrop model(api) do
    quote do: unquote(api).__exd_api__(:model)
  end


  @doc """
  Generic get function. There are different possiblities to get results. It possible to get results
  directly on `id`, on `name` (if defined in model). Or, due to query clauses.

  ## Examples

      iex> Exd.Api.Crud.get(api, %{"id" => 1})
      iex> Exd.Api.Crud.get(api, %{"name" => "test"})
      iex> Exd.Api.Crud.get(api, %{"where" => "id < 5", "limit" => "5"})

  ## Results

  Results to a list of found objects, and a list of links, attached to assoicated objects.

  """
  def get(api, %{"where" => _} = params) do
    select(api, params)
  end
  def get(api, params) do
    case get_one(api, params) do
      result when is_map(result) -> result |> export_data
      nil -> nil
    end
  end

  defp get_one(api, %{"id" => id} = params) do
    case repo(api).get(model(api), id) do
      nil    -> nil
      result -> result |> load(api, params)
    end
  end
  defp get_one(api, %{"name" => name} = params) do
    case repo(api).get_by(model(api), name: name) do
      nil    -> nil
      result -> result |> load(api, params)
    end
  end

  defp load(data, api, params) do
    repo(api).preload(data, Exd.Builder.Load.preload(params, model(api)))
  end

  defp select(api, params) do
    model = model(api)
    field_types = for field <- model.__schema__(:fields), do: {field, model.__schema__(:field, field)}
    from(m in model) |> Exd.Builder.Where.build(params, field_types)
                     |> Exd.Builder.QueryExpr.build(params)
                     |> Exd.Builder.Load.build(params)
                     |> (repo(api)).all
                     |> Enum.map(&export_data/1)
  end

  @doc """
  Generic insert function, which uses default changset implementation or model defined `changeset/3`
  function for validation, before inserting.

  ## Example of changset
    def changset(model, :create, params) do
      # Changeset on create
    end

  ## Results

  Results to an error of an link to object, which can be directly used in get.
  """
  def insert(api, params) when is_list(params), do: insert(api, :maps.from_list(params))
  def insert(api, params) do
    changeset = changeset(api.__exd_api__(:instance), api, :create, params)
    if changeset.valid? do
      repo(api).insert(changeset) |> export_data(as: :write)
    else
      %{errors: :maps.from_list(changeset.errors)}
    end
  end

  @doc """
  Generic put function, which uses default changset implementation or model defined `changeset/3`
  function for validation, before updating.

  ## Example of changset
    def changset(model, :update, params) do
      # Changeset on update
    end

  Results to an error of an link to object, which can be directly used in get.
  """
  def put(api, params) when is_list(params), do: put(api, :maps.from_list(params))
  def put(api, params) do
    if data = get_one(api, params), do: put(data, api, params)
  end

  @doc """
  Generic update on readed data.
  """
  def put(data, api, params) do
    changeset = changeset(data, api, :update, params)
    unmodified = params["if_unmodified_since"]
    changeset = if unmodified && Ecto.DateTime.to_iso8601(data.updated_at) != unmodified do
      Ecto.Changeset.add_error(changeset, :modified, "was modified since #{unmodified}")
    else changeset end

    if changeset.valid? do
      repo(api).update(changeset) |> export_data(as: :write)
    else
      %{errors: :maps.from_list(changeset.errors)}
    end
  end

  defp changeset(data, api, action, params) do
    if function_exported?(model(api), :changeset, 3) do
      api.model.changeset(data, action, params)
    else
      {required, optional} = if action == :create do
        {api.__exd_api__(:required), api.__exd_api__(:optional)}
      else
        {~W(), api.__exd_api__(:changable)}
      end
      Ecto.Changeset.cast(data, params, required, optional)
    end
  end

  @doc """
  Generic delete function, which deletes data on id or on name, if exists.
  """
  def delete(api, params) do
    case get_one(api, params) do
      nil    -> nil
      result -> repo(api).delete(result) |> export_data(as: :write)
    end
  end

  defp export_data(%{id: id} = data, opts \\ [as: :get]) do
    case opts[:as] do
      :get ->
        Map.drop(data, [:__meta__, :__struct__]) |> Enum.filter_map(&filter_assocs/1, &transform/1)
      :write ->
        %{id: id}
    end
  end

  defp filter_assocs({_key, %Ecto.Association.NotLoaded{}}), do: false
  defp filter_assocs({_key, _}), do: true

  # Brutal hack
  defp transform({key, %{__struct__: Ecto.DateTime} = struct}), do: {key, Ecto.DateTime.to_iso8601(struct)}
  defp transform({key, list}) when is_list(list), do: {key, Enum.map(list, &export_data/1)}
  defp transform({key, value}), do: {key, value}

  @default_crud [:get, :insert, :put, :delete]
  defmacro crud(opts \\ []) do
    actions = opts[:only] || @default_crud
    quote bind_quoted: [actions: actions] do
      if :insert in actions do
        api "insert", :__insert__
        @doc """
        Method: `insert`.
        Inserts #{String.downcase(@name)} object.

        ## Parameters

        #{ Exd.Api.Crud.description(@model, @exported, @read_only, @required, :insert) }
        """
        def __insert__(args), do: Exd.Api.Crud.insert(__MODULE__, args)
      end

      if :put in actions do
        api "put", :__put__
        @doc """
        Method: `put`.
        Update #{String.downcase(@name)} object.

        ## Parameters

        #{ Exd.Api.Crud.description(@model, @exported, @read_only, @required, :put) }
        """
        def __put__(args), do: Exd.Api.Crud.put(__MODULE__, args)
      end

      if :get in actions do
        api "get", :__get__
        @doc """
        Method: `get`.
        Get #{String.downcase(@name)} object.

        ## Parameters

        #{ Exd.Api.Crud.description(@model, @exported, @read_only, @required, :get) }
        """
        def __get__(args), do: Exd.Api.Crud.get(__MODULE__, args)
      end

      if :delete in actions do
        api "delete", :__delete__
        @doc """
        Method: `delete`.
        Delete #{String.downcase(@name)} object.

        ## Parameters

        #{ Exd.Api.Crud.description(@model, @exported, @read_only, @required, :delete) }
        """
        def __delete__(args), do: Exd.Api.Crud.delete(__MODULE__, args)
      end
    end
  end

  @doc """
  Generates description of method, based on model, exported, read_only and required fields and action.
  """
  def description(model, exported, read_only, required, action) when action in [:put, :insert] do
    changable = exported -- read_only
    optional = if action == :insert do changable -- required else changable end
    description = Enum.map(changable, fn(field) ->
      field_string(model, field, field in optional)
    end) |> Enum.join("\n")
    description <> update_attrs(action)
  end

  def description(model, exported, _read_only, _required, action) when action in [:get, :delete] do
    id_string   = if :id in exported do field_string(model, :id, false) <> "\n"     else "" end
    name_string = if :name in exported do field_string(model, :name, false) <> "\n" else "" end
    query_string = if action == :get do
    """
 * `where` - string, optional, identifies conditions on which it should be queried
 * `limit` - integer, optional, limit results of query
 * `load` - list of string, optional, identifies associations, which should be loaded
 * `offset` - integer, optional, offsets the number results
 * `order_by` - object, optional, set order of resulting query
 * `aggregate` - string, optional, aggregate information, available: `count`
    """
    else "" end
    id_string <> name_string <> query_string
  end

  defp field_string(model, field, optional) do
    optional_string = if optional do ", optional" else "" end
    type = model.__schema__(:field, field)
    " * `#{field}` - #{type}#{optional_string} #{model.__attribute_option__(field)[:desc] || ""}"
  end

  defp update_attrs(:insert), do: ""
  defp update_attrs(:put) do
"""
 * `if_unmodified_since` - string, optional, should be sent a value of `updated_at`, which can be readed on get.
"""
  end
end
