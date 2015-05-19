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
    end

    @doc """
    Implementation of `handle_request/4` for a service.
    """
    def handle_request(api, method, args) do
      method = String.split(method, ".") |> Enum.reverse |> hd
      {:ok, api.__apix__(:apply, method, args)}
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
          {:reply, Exd.Plugin.Hello.handle_request(__MODULE__, method, args), state}
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
    def route(context(session_id: id), request(method: method, args: _args = %{"resource" => resource}), uri) do
      case :hello_binding.lookup(uri, resource) do
        {:error, :not_found} -> {:error, :method_not_found}
        {:ok, _, name} -> {:ok, name, id}
      end
    end
  end
end
