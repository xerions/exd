if Code.ensure_loaded?(:hello) do
  defmodule Exd.Plugin.Hello do
    @moduledoc """
    Plugin for exporting model API with hello
    """

    @doc """
    Start hello listener, simplified as the most use case it needed. Please, see :hello.start_listener
    for more information.
    """
    def start_listener(uri \\ 'zmq-tcp://127.0.0.1:0', protocol \\ :hello_proto_jsonrpc, decoder \\ :hello_json) do
      :hello.start_listener(uri, [], protocol, [decoder: decoder], Exd.Plugin.Hello.Router)
      Exd.Plugin.Hello.Discovery.start
      :hello.bind(uri, Exd.Plugin.Hello.Discovery)
    end

    @doc """
    Implementation of `handle_request/4` for a service.
    """
    def handle_request(api, method, args, state) do
      result = if method in api.__apix__(:methods) do
                 introspection = api.__apix__(:apply, method, args)
                 remote_information = %{app: :exd, module: api}
                 {:ok, {:exd, introspection[:name], Map.merge(introspection, remote_information)}}
      else
        {:error, {:method_not_found, method, :null}}
      end
      {:stop, :normal, result, state}
    end

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
        def init(identifier, _), do: {:ok, nil}
        @doc false
        def handle_request(_context, method, args, state) do
          res = Exd.Plugin.Hello.handle_request(__MODULE__, method, args, state)
          {:reply, res, state}
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
    """
    require Record
    Record.defrecordp(:context, Record.extract(:context, from_lib: "hello/include/hello.hrl"))
    Record.defrecordp(:request, Record.extract(:request, from_lib: "hello/include/hello.hrl"))

    @doc """
    Implements route, see module documentation.
    """
    def route(context(session_id: id), request(method: _method, args: args) = req, uri) do
      uris = :hello_binding.binds_for_uri(uri)
      services = Enum.map(uris, fn({_ex_uri, _pid, name, _ref}) ->
        name
      end)
      {:ok, "exd/discovery", id, request(req, method: _method, args: Map.put(args, "services", services))}
    end
  end
end

defmodule Exd.Plugin.Hello.Discovery do
    @doc """
    Starts hello service.
    """
    def start(), do: :hello.start_service(__MODULE__, [])

    @doc false
    def name(), do: "exd/discovery"
    @doc false
    def router_key(), do: "discovery"
    @doc false
    def validation(), do: Exd.Plugin.Hello.Validation
    @doc false
    def init(_identifier, _), do: {:ok, nil}

    @doc false
    def handle_request(context, "options", %{"services" => service_list}, state) do
      res = Enum.map(service_list, fn(service) ->
        case service do
          "exd/discovery" ->
            []
          _ ->
            {_, _, {:ok,metadata}, _} = :hello.call_service(service, {"options", %{}})
            app = elem(metadata, 0) |> Atom.to_string
            metadata = Tuple.delete_at(metadata, 0)
            Map.put(%{}, app, [metadata] |> Enum.into(%{}))
        end
      end) |> :lists.flatten
      {:reply, {:ok, res}, state}
    end

    def handle_request(_context, _method, args, state) do
      module = args["module"] |> String.to_atom
      payload = args["payload"]
      result = Exd.Api.Crud.get(module, payload)
      {:stop, :normal, {:ok, result}, state}
    end

    @doc false
    def handle_info(_context, _message, state), do: {:noreply, state}
    @doc false
    def terminate(_context, _reason, _state), do: :ok
end
