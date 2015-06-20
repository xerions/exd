defmodule Exd.Escript.Remoter.Dist do
  @moduledoc """
  Exports function, which help local on node to inspect, how many apis are exported
  and where they are available for introspection. The same as helper to access it from erlang
  distributed helpers.
  """

  @doc """
  Macro for doing remote call, which sets group_leader to the local node and allows to use it, like
  it function call.

  ## Example

      iex> require Exd.Escript.Remoter.Dist, as: Dist
      ...> Dist.rpc(:node@host, Enum.sort([1,3,2]))
      [1,2,3]
  """
  defmacro rpc(node, {{:., _, [module, function]}, _, args}) do
    quote do
      :rpc.call(unquote(node), Exd.Escript.Remoter.Dist, :relay_apply, [unquote(module), unquote(function), unquote(args)])
    end
  end

  @doc """
  Remote helper for `rpc/2` macro.
  """
  def relay_apply(module, function, args) do
    :erlang.group_leader(Process.whereis(:user), self)
    apply(module, function, args)
  end

  @behaviour Exd.Escript.Remoter

  def applications(_) do
    init
    local_nodes |> Enum.map(fn(node) -> rpc(node, Exd.Escript.Remoter.Dist.apis) end)
                |> List.flatten
                |> Enum.into(%{})
  end

  def remote(_api = %{node: node, module: module}, method, payload) do
    rpc(node, module.__apix__(:apply, method, payload))
  end

  defp init() do
    known_digits = bin_node_names |> Enum.flat_map(&exd_name(&1))
    digit = Enum.max([0 | known_digits])
    :net_kernel.start([String.to_atom("exd_script#{digit + 1}"), :shortnames])
  end

  def local_nodes() do
    {:ok, hostname} = :inet.gethostname
    bin_node_names |> Enum.map(&(:"#{&1}@#{hostname}"))
  end

  defp bin_node_names() do
    System.cmd("epmd", ["-names"]) |> elem(0) |> String.split("\n") |> Enum.flat_map(&node_name(&1))
  end

  defp node_name(line) do
    case String.split(line) do
      ["name", node_name | _] -> [node_name]
      _ -> []
    end
  end

  defp exd_name("exd_script" <> digit), do: [String.to_integer(digit)]
  defp exd_name(_), do: []

  @doc """
  Returns list of applications and for every application APIs, which are available on node.
  """
  def apis() do
    for {app, _, _} <- :application.which_applications,
        modules = apis(app), modules != nil do
      {"#{app}", modules}
    end
  end

  @doc """
  Returns list of modules for an application, which are represent APIs.
  """
  def apis(app) do
    {:ok, modules} = :application.get_key(app, :modules)
    modules = for module <- modules, function_exported?(module, :__apix__, 0), do: module
    case modules do
      []      -> nil
      modules -> Stream.map(modules, &api_info(app, &1)) |> Enum.into(%{})
    end
  end

  defp api_info(app, module) do
    introspection = Apix.apply(module, "options", %{})
    remote_information = %{app: app, node: node, module: module}
    {introspection[:name], Map.merge(introspection, remote_information)}
  end
end
