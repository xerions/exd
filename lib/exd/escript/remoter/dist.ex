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
  defmacro rpc(node, {{:., _, [module, function]}, _, args}, cli_args) do
    quote do
      :rpc.call(unquote(node), Exd.Escript.Remoter.Dist, :relay_apply,
                [unquote(module), unquote(function), unquote(args) ++ unquote(cli_args)])
    end
  end

  @doc """
  Remote helper for `rpc/2` macro.
  """
  def relay_apply(module, function, args) do
    :erlang.group_leader(Process.whereis(:user), self)
    if function == :__apix__ do
      case args do
        [_, method, payload] -> module.__apix__(:apply, method, payload)
        [method, repo, module, payload] -> apply(module, method |> String.to_atom, [repo, payload])
      end
    else
      apply(module, function, [Enum.at(args, 1), Enum.at(args, 0)])
    end
  end

  def remote(path, method, params) do
    init
    result = Enum.map(local_nodes, fn(node) ->
      res = rpc(node, Exd.Router.apis, [path, method, params])
      case map_size(res) == 0 do
        true -> %{}
        false ->
          app_api = res[Exd.Router.app_name(path) |> String.to_atom]
          case (method == "options") or (method == "help") do
            true -> app_api
            _ -> send_query(node, path, app_api, method, params)
          end
      end
    end) |> :lists.flatten
    case (method == "options") or (method == "help") do
      true -> result |> response
      false -> result |> Enum.reduce(%{}, fn(app, acc) -> Map.merge(acc, app) end) |> response
    end
  end

  defp send_query(node, path, app_api, method, params) do
    if method in app_api.module_api.__apix__(:methods) do
      rpc(node, app_api.module_api.__apix__, [:apply, method, params]) |> format_result
    else
      rpc(node, app_api.module_api.__apix__, [method, app_api.repo, app_api.module_api, Map.put_new(params, "resource", path)]) |> format_result
    end
  end

  defp init() do
    known_digits = bin_node_names |> Enum.flat_map(&exd_name(&1))
    digit = Enum.max([0 | known_digits])
    :net_kernel.start([String.to_atom("exd_script#{digit + 1}"), :shortnames])
  end

  def local_nodes() do
    hostname = :net_adm.localhost |> List.to_string |> String.split(".") |> List.first
    bin_node_names |> Enum.map(&(:"#{&1}@#{hostname}"))
  end

  defp bin_node_names() do
    {:ok, names} = :net_adm.names
    for {name, _} <- names, do: :erlang.list_to_binary(name)  
  end

  defp exd_name("exd_script" <> digit), do: [String.to_integer(digit)]
  defp exd_name(_), do: []

  defp format_result(nil), do: %{}
  defp format_result(res), do: res

  defp response(result) when is_map(result) do
    case map_size(result) == 0 do
      true -> nil
      false -> result
    end
  end
  defp response(result), do: result
end
