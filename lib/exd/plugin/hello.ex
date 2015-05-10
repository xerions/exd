defmodule Exd.Plugin.Hello do
  def start_listener(uri \\ 'zmq-tcp://127.0.0.1:10900', protocol \\ :hello_proto_jsonrpc, decoder \\ :hello_msgpack) do
    :hello.start_listener(uri, [], protocol, [decoder: decoder], Exd.Plugin.Hello.Router)
  end

  def handle_request(api, method, args) do
    method = String.split(method, ".") |> Enum.reverse |> hd
    {:ok, api.__apix__(:apply, method, args)}
  end

  defmacro def_service(app) do
    name = __ENV__.module |> Module.get_attribute(:tech_name)
    quote do
      def start(), do: :hello.start_service(__MODULE__, [])

      def name(), do: unquote("#{app}/#{name}")
      def router_key(), do: @tech_name
      def validation(), do: Exd.Plugin.Hello.Validation

      def init(identifier, _), do: {:ok, nil}
      def handle_request(_context, method, args, state) do
        {:reply, Exd.Plugin.Hello.handle_request(__MODULE__, method, args), state}
      end

      def handle_info(_context, _message, state), do: {:noreply, state}
      def terminate(_context, _reason, _state), do: :ok
      defoverridable [name: 0, router_key: 0, validation: 0,
                      init: 2, handle_request: 4,
                      handle_info: 3, terminate: 3]
    end
  end
end

defmodule Exd.Plugin.Hello.Validation do
  def request(_api, method, params) do
    {:ok, method, params}
  end
end

defmodule Exd.Plugin.Hello.Router do
  require Record
  Record.defrecordp(:context, Record.extract(:context, from_lib: "hello/include/hello.hrl"))
  Record.defrecordp(:request, Record.extract(:request, from_lib: "hello/include/hello.hrl"))

  def route(context(session_id: id), request(method: method, args: args), uri) do
    IO.inspect({method, args, uri})
    {:ok, :test, id}
  end
end
