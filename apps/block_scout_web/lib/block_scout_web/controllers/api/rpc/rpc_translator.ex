defmodule BlockScoutWeb.API.RPC.RPCTranslator do
  @moduledoc """
  Converts an RPC-style request into a controller action.

  Requests are expected to have URL query params like `?module=module&action=action`.

  ## Configuration

  The plugs needs a map relating a `module` string to a controller module.

      # In a router
      forward "/api", RPCTranslator, %{"block" => BlockController}

  """

  import Plug.Conn

  alias BlockScoutWeb.API.RPC.RPCView
  alias Plug.Conn
  alias Phoenix.Controller

  def init(opts), do: opts

  def call(%Conn{params: %{"module" => module, "action" => action}} = conn, translations) do
    with {:ok, controller} <- translate_module(translations, module),
         {:ok, action} <- translate_action(action),
         {:ok, conn} <- call_controller(conn, controller, action) do
      conn
    else
      _ ->
        conn
        |> put_status(400)
        |> Controller.render(RPCView, :error, error: "Unknown action")
        |> halt()
    end
  end

  def call(%Conn{} = conn, _) do
    conn
    |> put_status(400)
    |> Controller.render(RPCView, :error, error: "Params 'module' and 'action' are required parameters")
    |> halt()
  end

  @doc false
  @spec translate_module(map(), String.t()) :: {:ok, module()} | :error
  def translate_module(translations, module) do
    module_lowercase = String.downcase(module)
    Map.fetch(translations, module_lowercase)
  end

  @doc false
  @spec translate_action(String.t()) :: {:ok, atom()} | :error
  def translate_action(action) do
    action_lowercase = String.downcase(action)
    {:ok, String.to_existing_atom(action_lowercase)}
  rescue
    ArgumentError -> :error
  end

  @doc false
  @spec call_controller(Conn.t(), module(), atom()) :: {:ok, Conn.t()} | :error
  def call_controller(conn, controller, action) do
    {:ok, controller.call(conn, action)}
  rescue
    Conn.WrapperError -> :error
  end
end
