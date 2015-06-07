defmodule Exd.Escript.Remoter.Zmtp do
  @moduledoc """
  Exports function, which help local on node to inspect, how many apis are exported
  and where they are available for introspection, based on zmtp.
  """

  @behaviour Exd.Escript.Remoter

  def applications() do
    init_zmtp
    :hello_client.start_link({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', {[], [], []})
    :hello_client.call(__MODULE__, {"options", [], []})
  end

  def remote(_api, _method, _payload) do
    :test
  end

  def init_zmtp() do
    Application.put_env :sasl, :sasl_error_logger, :false, persistent: true
    Application.put_env :lager, :handlers, [], persistent: true
    Application.ensure_all_started(:ezmq)
    Application.get_env(:exd, :test) |> IO.inspect
  end

end
