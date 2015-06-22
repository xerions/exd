defmodule Exd.Escript.Remoter.Zmtp do
  @moduledoc """
  Exports function, which help local on node to inspect, how many apis are exported
  and where they are available for introspection, based on zmtp.
  """

  @behaviour Exd.Escript.Remoter

  def applications(_) do
    init_zmtp
    {:ok, client} = :hello_client.start_link({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', {[], [], []})
    Tuple.insert_at(:hello_client.call(__MODULE__, {"options", %{}, []}), 2, %{client: client})
  end

  def remote(api, method, payload, opts) do
    metadata = %{}
    metadata = Map.put_new(metadata, :module, api["module"] |> String.to_atom)
    metadata = Map.put_new(metadata, :payload, payload)
    {:ok, response} = :hello_client.call(opts[:client], {method, metadata, []})
    :hello_client.stop(__MODULE__)
    response
  end

  def init_zmtp() do
    Application.put_env :sasl, :sasl_error_logger, :false, persistent: true
    Application.put_env :lager, :handlers, [], persistent: true
    Application.ensure_all_started(:ezmq)
    Application.get_env(:exd, :test) |> IO.inspect
  end
end
