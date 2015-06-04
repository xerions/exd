defmodule Exd.Api.Callbacks do
  @moduledoc """
  Define api-level callbacks. Heavily inspired by `Ecto.Model.Callbacks`

  A callback is invoked by your `Api` after particular events. Lifecycle
  callbacks always receive a changeset and models and do need to return
  something.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Exd.Api.Callbacks
      @before_compile Exd.Api.Callbacks
      @exd_callbacks %{}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    callbacks = Module.get_attribute env.module, :exd_callbacks

    for {event, callbacks} <- callbacks do
      body = Enum.reduce Enum.reverse(callbacks), quote(do: changeset), &compile_callback/2

      quote do
        def unquote(event)(changeset), do: unquote(body)
      end
    end
  end

  @doc """
  ## Example

      after_put Api, :notify

  """
  defmacro after_put(function, args \\ []),
    do: register_callback(:after_put, function, args, [])

  @doc """
  Same as `after_put/2` but with arguments.
  """
  defmacro after_put(module, function, args),
    do: register_callback(:after_put, module, function, args)

  @doc """
  ## Example

      after_post Api, :notify

  """
  defmacro after_post(function, args \\ []),
    do: register_callback(:after_post, function, args, [])

  @doc """
  Same as `after_post/2` but with arguments.
  """
  defmacro after_post(module, function, args),
    do: register_callback(:after_post, module, function, args)


  @doc """
  ## Example

      after_delete Api, :notify

  """
  defmacro after_delete(function, args \\ []),
    do: register_callback(:after_delete, function, args, [])

  @doc """
  Same as `after_delete/2` but with arguments.
  """
  defmacro after_delete(module, function, args),
    do: register_callback(:after_delete, module, function, args)

  defp register_callback(event, module, function, args) do
    quote bind_quoted: binding() do
      callback = {module, function, args}
      @exd_callbacks Map.update(@exd_callbacks, event, [callback], &[callback|&1])
    end
  end

  defp compile_callback({function, args, []}, acc)
      when is_atom(function) and is_list(args) do
    quote do
      unquote(function)(unquote(acc), unquote_splicing(Macro.escape(args)))
    end
  end

  defp compile_callback({module, function, args}, acc)
      when is_atom(module) and is_atom(function) and is_list(args) do
    quote do
      unquote(module).unquote(function)(unquote(acc), unquote_splicing(Macro.escape(args)))
    end
  end

  @doc """
  Applies stored callbacks in model to given data.
  """
  def __apply__(module, callback, %{__struct__: expected} = data) do
    if function_exported?(module, callback, 1) do
      case apply(module, callback, [data]) do
        %{__struct__: ^expected} = data ->
          data
        other ->
          raise ArgumentError,
            "expected `#{callback}` callbacks to return a #{inspect expected}, got: #{inspect other}"
      end
    else
      data
    end
  end
end
