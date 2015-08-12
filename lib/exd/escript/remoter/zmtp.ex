defmodule Exd.Escript.Remoter.Zmtp do
  @moduledoc """
  Exports function, which help local on node to inspect, how many apis are exported
  and where they are available for introspection, based on zmtp.
  """

  @behaviour Exd.Escript.Remoter

  def applications(_) do
    init_zmtp
    {:ok, zmq_address} = :application.get_env(:exd, :addr)
    Hello.Client.start_link({:local, __MODULE__}, zmq_address, {[], [], []})
    {:ok, apps} = Hello.Client.call(__MODULE__, {"options", %{}, []})
    apps
  end

  def remote(api, method, payload) do
    metadata = %{} |> Map.put_new(:module, api["module"] |> String.to_atom) 
                   |> Map.put_new(:payload, payload)
    {:ok, response} = Hello.Client.call(__MODULE__, {method, metadata, []})
    response
  end

  def init_zmtp() do
    Application.put_env :sasl, :sasl_error_logger, :false, persistent: true
    Application.put_env :lager, :handlers, [], persistent: true
    Application.ensure_all_started(:ezmq)
    Application.get_env(:exd, :test) |> IO.inspect
  end
end
