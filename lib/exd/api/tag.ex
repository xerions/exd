defmodule Exd.Api.Tag do
  @moduledoc """
  The module provides post/get/delete implementation for the tags API.

  ## Example of definition

      import Exd.Model

      model Example do
        field :test1
        field :test2
      end

      defmodule Example.Api do
        @moduledoc "Example module documentation"
        @name "Example"
        @tech_name "example"
        use Exd.Api, repo: Example.Repo, apis: [Exd.Api.Tag]
      end
  """

  @name "Tag"
  @tech_name "tag"

  use Exd.Api, model: Exd.Model.Dummy

  import Exd.Plugin.Hello
  def_service("exd")

  def post(repo, params) do
    {tagname, tagvalue,  model, params} = get_data_for_tag(params)
    Ecto.Taggable.Api.set_tag(repo, model |> repo.get_by(params), tagname, tagvalue)
  end

  def get(repo, params) do
    {tagname, tagvalue, model, _params} = get_data_for_tag(params)
    Ecto.Taggable.Api.search_tag(repo, model, tagname, tagvalue)
  end

  def delete(repo, params) do
    {_tagname, tagvalue, model, params} = get_data_for_tag(params)
    case params do
      [] -> Ecto.Taggable.Api.drop_tag(repo, model, tagvalue, tagvalue)
      _ ->  Ecto.Taggable.Api.drop_tag(repo, model |> repo.get_by(params), tagvalue, tagvalue)
    end
  end

  @doc false
  defp get_data_for_tag(params) do
    [app, model | _] = String.split(params["resource"], "/")
    module_api = Exd.Router.apis("post", params["resource"])
    tagname = params["tag"] |> String.to_atom
    tagvalue = params["tag_value"]
    params = Map.delete(params, "tag")
    params = Map.delete(params, "tag_value")
    params = Map.delete(params, "resource")
    params = Enum.map(params, fn({k, v}) -> {k |> String.to_atom, v} end)
    model = (module_api[app |> String.to_atom][model][:module]).__exd_api__(:model)
    {tagname, tagvalue, model, params}
  end
end
