defmodule Exd.Api.Export do
  @moduledoc """
  """

  defmacrop repo(api) do
    quote do: unquote(api).__exd_api__(:repo)
  end
  defmacrop model(api) do
    quote do: unquote(api).__exd_api__(:model)
  end

  defmacro export(opts \\ []) do
    actions = [:get, :post, :delete]
    quote bind_quoted: [actions: actions] do
      if :post in actions do
        api "export_post", :__export_post__
        api "import_post", :__export_post__
        @doc """
        Method: `post`.
        Inserts #{String.downcase(@name)} object.

        ## Parameters

        """
        def __export_post__(args), do: Ecto.Export.create(@repo, [@model], args)
      end

      if :get in actions do
        api "export_get", :__export_get__
        api "import_get", :__export_get__
        @doc """
        Method: `get`.
        Get #{String.downcase(@name)} object.

        ## Parameters

        """
        def __export_get__(%{"id" => id}), do: Ecto.Export.check(String.to_integer(id))
      end

      if :delete in actions do
        api "export_delete", :__export_delete__
        api "import_delete", :__export_delete__
        @doc """
        Method: `delete`.
        Delete #{String.downcase(@name)} object.

        ## Parameters

        """
        def __export_delete__(%{"id" => id}), do: Ecto.Export.stop(String.to_integer(id))
      end
    end
  end
end
