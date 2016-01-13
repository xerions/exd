if Code.ensure_loaded?(:hello) do
  defmodule Exd.Plugin.Hello do
    @moduledoc """
    Plugin for exporting model API with hello
    """

    @doc """
    Start hello listener, simplified as the most use case it needed. Please, see :hello.start_listener
    for more information.
    """
    
    def start_listener(uri \\ 'zmq-tcp://127.0.0.1:0', name \\ :undefined) do
      :hello.start_listener(name, uri, [], :hello_proto_jsonrpc, [decoder: :hello_json], Exd.Plugin.Hello.Router)
    end

    @doc """
    Implementation of `handle_request/4` for a service.
    """
    def handle_request(api, method, args, state) do
      result = if method in api.__apix__(:methods) do
                 {:ok, nil2null(api.__apix__(:apply, method, args))}
               else
                 if function_exported?(api, method |> String.to_atom, 2) do
                   {:ok, nil2null(apply(api, method |> String.to_atom, [state[:repo], args]))}
                 else
                   {:error, {:method_not_found, method, :null}}
                 end
               end
      {:stop, :normal, result, state}
    end

    defp nil2null(%{} = map) do
      try do
        Enum.map(map, fn({key, value}) -> {key, nil2null(value)} end) |> Enum.into(%{})
      rescue _ in _ ->
          Enum.map(Map.from_struct(map), fn({key, value}) -> {key, nil2null(value)} end) |> Enum.into(%{})
      end
    end
    defp nil2null(list) when is_list(list) do
      Enum.map(list, &nil2null/1)
    end
    defp nil2null(nil), do: :null
    defp nil2null(value), do: value

    @doc """
    Exports the API as hello service. It defines the name, based on `app` option and @tech_name as
    `app/@tech_name` for dns registration.

    It sets validation to `Exd.Plugin.Hello.Validation`, which doesn't perform validation, as the
    validation are based on ecto.

    It gives the default implementation for all needed callbacks, which are overridable.
    """
    defmacro def_service(app) do
      quote do
        @doc """
        Starts hello service.
        """
        def start(), do: :hello.start_service(__MODULE__, [])

        @doc false
        def name(), do: "#{unquote(app)}/#{@tech_name}"
        @doc false
        def router_key(), do: @tech_name
        @doc false
        def validation(), do: Exd.Plugin.Hello.Validation

        @doc false
        def init(identifier, state) do
          {:ok, state}
        end
        @doc false
        def handle_request(_context, method, args, state) do
          Exd.Plugin.Hello.handle_request(__MODULE__, method, args, state)
        end

        @doc false
        def handle_info(_context, _message, state), do: {:noreply, state}
        @doc false
        def terminate(_context, _reason, _state), do: :ok
        defoverridable [name: 0, router_key: 0, validation: 0,
                        init: 2, handle_request: 4,
                        handle_info: 3, terminate: 3]
      end
    end
  end

  defmodule Exd.Plugin.Hello.Validation do
    @doc """
    For not performing of validation, reserved for performing validations in future.
    """
    def request(_api, method, params) do
      {:ok, method, params}
    end
  end

  defmodule Exd.Plugin.Hello.Router do
    @moduledoc """
    Overwrites default hello router, to use instead of `Resource.method` the scheme, `method` and
    `resource` as parameter.

    If `resource` isn't found default hello router will be used.
    """
    require Record
    Record.defrecordp(:context, Record.extract(:context, from_lib: "hello/include/hello.hrl"))
    Record.defrecordp(:request, Record.extract(:request, from_lib: "hello/include/hello.hrl"))

    @doc """
    Implements route, see module documentation.
    """
    def route(context(session_id: id) = ctx, request(method: method, args: args) = req, uri) do
      case args["resource"] do
        nil -> :hello_router.route(ctx, req, uri)
        resource -> 
          paths = String.split(resource, "/")
          resource_len = length(paths)
          cond do
            resource_len == 1 ->
              case :hello_binding.lookup(uri, resource) do
                {:error, :not_found} -> {:error, :method_not_found}
                {:ok, _, name} -> {:ok, name, id}
              end
            resource_len == 2 ->
              res = Enum.filter(:hello_binding.all, fn({_,_,r,_}) -> r == resource end)
              case res do
                [] -> {:error, :method_not_found}
                _ ->  {:ok, resource, id}
              end
            resource_len == 3 ->
              app = Enum.at(paths, 0) |> String.to_atom
              module_api = Exd.Router.apis(method, resource)
              case module_api do
                nil ->
                  {:error, :method_not_found}
                  _ ->
                  {:ok, module_api[app].module_api.name, id}
              end
            resource_len > 3 or resource_len < 1 ->
              {:error, :method_not_found}
          end
      end
    end
  end
end
