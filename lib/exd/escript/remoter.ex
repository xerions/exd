defmodule Exd.Escript.Remoter do
  @moduledoc """
  Implements remote pluggable interface
  """
  use Behaviour

  @doc "Method of getting remote applications"
  defcallback applications(script :: term()) :: term()

  @doc "Call remote method on payload"
  defcallback remote(api :: term(), method :: binary(), payload :: term()) :: term()

  @doc "Export all data for api"
  defcallback export(api :: term(), method :: binary(), payload :: term()) :: term()

  @doc "Import all data for api"
  defcallback import(api :: term(), method :: binary(), payload :: term()) :: term()

  def get("dist"), do: Exd.Escript.Remoter.Dist
  def get("zmtp"), do: Exd.Escript.Remoter.Zmtp
  def get(_),      do: nil
end
