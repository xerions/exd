defmodule Exd.Escript.Remoter.Zmtp do
  @moduledoc """
  Exports function, which help local on node to inspect, how many apis are exported
  and where they are available for introspection, based on zmtp.
  """

  @behaviour Exd.Escript.Remoter

  def applications() do
    Application.ensure_all_started(:hello)
    :hello_client.start({:local, __MODULE__}, 'zmq-tcp://127.0.0.1:10900', [], [decoder: :hello_msgpack], [])
    :hello_client.call(__MODULE__, {"options", [], []})
  end

  def remote(_api, _method, _payload) do
    :test
  end
end
