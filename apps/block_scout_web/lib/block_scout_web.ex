defmodule BlockScoutWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BlockScoutWeb, :controller
      use BlockScoutWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """
  def version(), do: Application.get_env(:block_scout_web, :version)
  def segment_key(), do: Application.get_env(:block_scout_web, :segment_key)
  def network_path(), do: Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:path]
  def coin_name(), do: Application.get_env(:explorer, :coin_name)
  def subnetwork(), do: Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:subnetwork]
  def chain_id(), do: Application.get_env(:block_scout_web, :chain_id)
  def json_rpc(), do: Application.get_env(:block_scout_web, :json_rpc)

  def controller do
    quote do
      use Phoenix.Controller, namespace: BlockScoutWeb

      import BlockScoutWeb.Controller
      import BlockScoutWeb.Router.Helpers
      import BlockScoutWeb.WebRouter.Helpers, except: [static_path: 2]
      import BlockScoutWeb.Gettext
      import BlockScoutWeb.ErrorHelpers
      import Plug.Conn

      alias BlockScoutWeb.AdminRouter.Helpers, as: AdminRoutes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/block_scout_web/templates",
        namespace: BlockScoutWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import BlockScoutWeb.{
        CurrencyHelpers,
        ErrorHelpers,
        Gettext,
        Router.Helpers,
        TabHelpers,
        Tokens.Helpers,
        Views.ScriptHelpers,
        WeiHelpers
      }

      import BlockScoutWeb.WebRouter.Helpers, except: [static_path: 2]
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      import BlockScoutWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
