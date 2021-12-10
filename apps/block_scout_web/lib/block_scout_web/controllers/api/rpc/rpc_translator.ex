defmodule BlockScoutWeb.API.RPC.RPCTranslator do
  @moduledoc """
  Converts an RPC-style request into a controller action.

  Requests are expected to have URL query params like `?module=module&action=action`.

  ## Configuration

  The plugs needs a map relating a `module` string to a controller module.

      # In a router
      forward "/api", RPCTranslator, %{"block" => BlockController}

  """

  require Logger
  require APILogger

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2]

  alias BlockScoutWeb.API.RPC.RPCView
  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{params: %{"module" => module, "action" => action}} = conn, translations) do
    with {:ok, {controller, write_actions}} <- translate_module(translations, module),
         {:ok, action} <- translate_action(action),
         true <- action_accessed?(action, write_actions),
         {:ok, conn} <- call_controller(conn, controller, action) do
      APILogger.log(conn)
      conn
    else
      {:error, :no_action} ->
        conn
        |> put_status(400)
        |> put_view(RPCView)
        |> Controller.render(:error, error: "Unknown action")
        |> halt()

      {:error, error} ->
        Logger.error(fn -> ["Error while calling RPC action", inspect(error)] end)

        conn
        |> put_status(500)
        |> put_view(RPCView)
        |> Controller.render(:error, error: "Something went wrong.")
        |> halt()

      _ ->
        conn
        |> put_status(500)
        |> put_view(RPCView)
        |> Controller.render(:error, error: "Something went wrong.")
        |> halt()
    end
  end

  def call(%Conn{} = conn, _) do
    conn
    |> put_status(400)
    |> put_view(RPCView)
    |> Controller.render(:error, error: "Params 'module' and 'action' are required parameters")
    |> halt()
  end

  @doc false
  @spec translate_module(map(), String.t()) :: {:ok, {module(), list(atom())}} | {:error, :no_action}
  defp translate_module(translations, module) do
    module_lowercase = String.downcase(module)

    case Map.fetch(translations, module_lowercase) do
      {:ok, module} -> {:ok, module}
      _ -> {:error, :no_action}
    end
  end

  @doc false
  @spec translate_action(String.t()) :: {:ok, atom()} | {:error, :no_action}
  defp translate_action(action) do
    action_lowercase = String.downcase(action)
    {:ok, String.to_existing_atom(action_lowercase)}
  rescue
    ArgumentError -> {:error, :no_action}
  end

  defp action_accessed?(action, write_actions) do
    conf = Application.get_env(:block_scout_web, BlockScoutWeb.ApiRouter)

    if action in write_actions do
      conf[:writing_enabled] || {:error, :no_action}
    else
      conf[:reading_enabled] || {:error, :no_action}
    end
  end

  @doc false
  @spec call_controller(Conn.t(), module(), atom()) :: {:ok, Conn.t()} | {:error, :no_action} | {:error, Exception.t()}
  defp call_controller(conn, controller, action) do
    if :erlang.function_exported(controller, action, 2) do
      {:ok, controller.call(conn, action)}
    else
      {:error, :no_action}
    end
  rescue
    e ->
      {:error, Exception.format(:error, e, __STACKTRACE__)}
  end
end
