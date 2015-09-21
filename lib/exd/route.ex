defmodule Exd.Router do

  def get_module_api(modules, [path | rest] = paths) do
    mods = Enum.filter(modules, fn(exd_api_module) -> exd_api_module.__apix__ == path end)
    mods = Enum.map(mods, fn(exd_api_module) -> {exd_api_module.__exd_api__(:repo), exd_api_module} end)
    get_module_api_helper(mods, rest)
  end

  defp get_module_api_helper([], _), do: nil
  defp get_module_api_helper([{repo, module}], []), do: {repo, module}
  defp get_module_api_helper(mods, [path | rest]) do
    case mods do
      [] -> nil
      mods ->
        mods = Enum.map(mods, fn({repo, exd_api_module}) ->
          {repo, exd_api_module.__exd_api__(:apis)}
        end) |> :lists.flatten
        [{repo, modules}] = mods
        mods = Enum.filter_map(modules, fn(exd_api_module) -> exd_api_module.__apix__ == path end, &{repo, &1})
        get_module_api_helper(mods, rest)
    end
  end

  def apis(method, resource) do
    apis = fn (app) ->
      {:ok, modules} = :application.get_key(app, :modules)
      modules = for module <- modules, app_loaded?(module, resource, app), do: module
      case modules do
        []      -> %{}
        modules -> Stream.map(modules, &api_info(app, &1, resource, method)) |> Enum.into(%{})
      end
    end
    Enum.map(:application.which_applications, fn({app, _, _}) -> app end) |> Enum.reduce(%{}, fn(app, acc) -> Map.merge(acc, apis.(app)) end)
  end

  defp app_loaded?(module, resource, app) do
    resource_app = app_name(resource) |> String.to_atom
    :code.is_loaded(module) == false and :code.load_file(module)
    case function_exported?(module, :__exd_api__, 1) do
      true -> (apply(module, :__exd_api__, [:app])) and (apply(module, :__exd_api__, [:tech_name]) == resource_app)
      false -> false
    end
  end

  defp api_info(app, module, resource, method) do
    [_ | paths] = String.split(resource, "/")
    introspection = Apix.apply(module, "options", %{})
    remote_information = %{app: app, node: node}
    case (method == "options") or (method == "help") do
      true -> {introspection[:name], Map.merge(introspection, remote_information)}
      _ ->
        case Exd.Router.get_module_api(module.__exd_api__(:apis), paths) do
          nil -> nil
          {repo, module_api} ->
            {introspection[:name], Map.merge(introspection, remote_information)
             |> Map.put_new(:module_api, module_api)
             |> Map.put_new(:repo, repo)}
        end
    end
  end

  def app_name(resource), do: String.split(resource, "/") |> List.first 
end
