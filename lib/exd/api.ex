defmodule Exd.Model.Api do
  import Ecto.Query
  import Exd.Util

  @doc """
  Generate new module with model API.

  Usage:
    gen_api MyApp.User MyApp.Repo

  Result:
    MyApp.User.Api module with introspection API
  """
  defmacro gen_api({_, _, splitten_module_name} = model, repo) do
    api_module_name = extend_module_name(Module.concat(splitten_module_name), ".Api")
    quote location: :keep do
      defmodule unquote(api_module_name) do
        import Exd.Util
        import Ecto.Query

        def introspection do
          fields = unquote(model).__schema__(:fields)
          associations = get_associations(unquote(model))
          fields = for field <- fields do
            case List.keyfind(associations, field, 0) do
              {_, table, _} -> {field, :integer, table}
              nil -> {field, unquote(model).__schema__(:field, field), ""}
            end
          end
          actions = unquote(model).__info__(:functions) |> Enum.flat_map(fn({function, _}) ->
            case to_string(function) do
              "__action__" <> action ->
                [action]
              _ ->
                []
            end
          end)
          {fields, ["insert", "get", "update", "select" | actions]}
        end

        def empty_query(), do: from(table in unquote(model))

        def delete_all(),  do: unquote(repo).delete_all(unquote(model))
        def delete(entry), do: unquote(repo).delete(entry)
        def select(query), do: unquote(repo).all(query)

        def select_on(query_content) do
          {_primary_key, fields_with_types} = __field_types__()
          Exd.Builder.Where.build(empty_query, query_content, fields_with_types) |> Exd.Builder.QueryExpr.build(query_content) |> select
        end

        def select(query) do
          model = unquote(model)
          # get all fields for this model with thier types
          {_primary_key, fields_with_types} =  __field_types__()
          # get associations
          associations = unquote(model).__schema__(:associations)
          # build empty query
          empty_query = from table in model, preload: ^associations, select: table
          #
          # find where clause and build it if it is
          #
          is_where_clause = List.keyfind(query, :where, 0)
          where_str = case is_where_clause do
                        nil -> ""
                        {:where, where_clause} ->
                          for element <- where_clause do
                            case element do
                              {key, op, val} ->
                                (key |> Atom.to_string) <> " " <> (op |> Atom.to_string) <> " " <> Kernel.to_string(val)
                              op ->
                                (op |> Atom.to_string)
                            end
                          end |> Enum.join(" ")
                      end

          # update query with where clause
          where_struct = Exd.Builder.Where.build_where_clause_from_string(where_str, fields_with_types)
          # update query with limit clause
          formed_query = Map.put(empty_query, :wheres, [%Ecto.Query.QueryExpr{__struct__: :'Elixir.Ecto.Query.QueryExpr', expr: where_struct}])

          formed_query = __query_clause_helper__(query, formed_query, :limit)
          formed_query = __query_clause_helper__(query, formed_query, :offset)
          formed_query = __query_clause_helper__(query, formed_query, :distincts)

          # Execute query
          select(formed_query)
        end

        def __query_clause_helper__(query, query_content, field) do
          case List.keyfind(query, field, 0) do
            nil ->
              query_content
            {field, val} ->
              Map.put(query_content, field, %Ecto.Query.QueryExpr{__struct__: :'Ecto.Query.QueryExpr', expr: val})
          end
        end

        def insert(params) when is_list(params), do: insert(:maps.from_list(params))
        def insert(params) do
          required = (for name <- unquote(model).__schema__(:fields), do: to_string(name))
          changeset = Ecto.Changeset.cast(%unquote(model){}, params, required, ~w())
          if changeset.valid? do
            _ = unquote(repo).insert(changeset)
          else
            {:error, changeset.errors}
          end
        end

        def update(entry, params) when is_list(params), do: update(entry, :maps.from_list(params))
        def update(entry, params) do
          optional = (for name <- unquote(model).__schema__(:fields), do: to_string(name))
          changeset = Ecto.Changeset.cast(entry, params, ~w(), optional)
          if changeset.valid? do
            _ = unquote(repo).update(changeset)
          else
            {:error, changeset.errors}
          end
        end

        def subscribe(sub_info, options) do
          Ecto.Subscribe.Api.subscribe(unquote(repo), unquote(model), sub_info, options)
        end

        def get(id) do
          # get table name to prevent has_many return
          table_name = table_name(unquote(model))
          # get associations list
          assoc_list = unquote(model).__schema__(:associations)
          # load model
          load_model = unquote(repo).get Module.concat(unquote(splitten_module_name)), id, log: false
          case load_model do
            nil -> nil
            _ -> unquote(repo).preload([load_model], assoc_list)
          end
        end

        @doc """
        Return associations
        """
        def __associations__(model) do
          model.__schema__(:associations)
        end

        @doc """
        Return the name of a table
        """
        def __tablename__(model) do
          table_name(model)
        end

        @doc """
        Return list of {field_name, type} including association field.
        """
        def __field_types__() do
          model = unquote(model)
          primary_key = model.__schema__(:primary_key)
          assocs = get_associations(model)
          {primary_key, for name <- model.__schema__(:fields) do
            case assocs[name] do
              nil ->
                {name, model.__schema__(:field, name)}
              _ ->
                {name, Ecto.Migration.references(assocs[name]).type}
            end
          end}
        end
        defdelegate [__schema__(target), __schema__(target, id)], to: unquote(model)
      end
    end
  end

end
