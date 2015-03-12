defmodule Exd.Model.Api do
  import Ecto.Query
  import Exd.Model.Util

  @doc """
  Generate new module with model API.

  Usage:
    gen_api MyApp.User MyApp.Repo

  Result:
    MyApp.User.Api module with introspection API
  """
  defmacro gen_api({_, _, splitten_module_name} = model, repo) do
    api_module_name = extend_module_name(Module.concat(splitten_module_name), ".Api")
    #
    # generate new module
    #
    quote do
      defmodule unquote(api_module_name) do

        def show do
          unquote(model).__introspection__
        end

        def delete_all(model) do
          unquote(repo).delete_all(model, log: false)
        end

        def delete(query) do
          case select(query) do
            [] ->
              :not_found
            [res] ->
              unquote(repo).delete(res, log: false)
          end
        end

        def update(record) do
          unquote(repo).update(record, log: false)
        end

        def select(query) do
          unquote(repo).all(query, log: false)
        end

        def select(model, query) do
          require Ecto.Query
          # get all fields for this model with thier types
          {_primary_key, fields_with_types} =  __get_fields_with_types__(model)
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
                          Enum.reduce(where_clause, "",
                                      fn(element, acc) ->
                                        case element do
                                          {key, op, val} ->
                                            acc <> (key |> Atom.to_string) <> " " <> (op |> Atom.to_string) <> " " <> Kernel.to_string(val) <> " "
                                          op ->
                                            acc <> (op |> Atom.to_string) <> " "
                                        end
                                      end)
                      end

          # update query with where clause
          where_struct = Mix.Tasks.Compile.Query.Builder.Where.build_where_clause_from_string(where_str, fields_with_types)
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

        def insert(record) do
          unquote(repo).insert(record, log: false)
        end

        def get(id) do
          # get table name to prevent has_many return
          table_name = table_name(unquote(model))
          # get associations list
          assoc_list = unquote(model).__schema__(:associations)

          case assoc_list do
            [] ->
              case unquote(repo).get Module.concat(unquote(splitten_module_name)), id, log: false do
                nil -> {table_name, assoc_list, nil}
                load_model -> {table_name, assoc_list, [load_model]}
              end
            _ ->
              # load model
              load_model = unquote(repo).get Module.concat(unquote(splitten_module_name)), id, log: false
              case load_model do
                nil -> {table_name, assoc_list, nil}
                _ ->   {table_name, assoc_list, unquote(repo).preload([load_model], assoc_list)}
              end
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
        def __get_fields_with_types__(model) do
          primary_key = model.__schema__(:primary_key)
          assocs = model.__schema__(:associations) |> Enum.flat_map(fn(association) ->
            case model.__schema__(:association, association) do
              %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_model} ->
                [{field, table_name(assoc_model)}]
              _ ->
                []
            end
          end)
          {primary_key, for name <- model.__schema__(:fields) do
            case assocs[name] do
              nil ->
                {name, model.__schema__(:field, name)}
              _ ->
                {name, Ecto.Migration.references(assocs[name]).type}
            end
          end}
        end
      end # endof defmodule api_module_name
    end # endof quote do:
  end # endof defmacro 

end
