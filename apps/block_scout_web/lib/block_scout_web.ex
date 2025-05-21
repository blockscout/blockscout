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

  def controller do
    quote do
      use Phoenix.Controller, namespace: BlockScoutWeb

      import BlockScoutWeb.Controller
      import BlockScoutWeb.Router.Helpers
      import BlockScoutWeb.Routers.WebRouter.Helpers, except: [static_path: 2]
      use Gettext, backend: BlockScoutWeb.Gettext
      import BlockScoutWeb.ErrorHelper
      import BlockScoutWeb.Routers.AccountRouter.Helpers, except: [static_path: 2]
      import Plug.Conn

      import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
        only: [proxy_implementations_association: 0, proxy_implementations_smart_contracts_association: 0]

      alias BlockScoutWeb.Routers.AdminRouter.Helpers, as: AdminRoutes

      alias BlockScoutWeb.Schemas.API.V2, as: Schemas
      alias OpenApiSpex.{Schema, Reference}
      alias OpenApiSpex.JsonErrorResponse
      alias Schemas.ErrorResponses.ForbiddenResponse

      import BlockScoutWeb.Schemas.API.V2.General
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
        CurrencyHelper,
        ErrorHelper,
        Router.Helpers,
        TabHelper,
        Tokens.Helper,
        Views.ScriptHelper,
        WeiHelper
      }

      use Gettext, backend: BlockScoutWeb.Gettext

      import BlockScoutWeb.Routers.AccountRouter.Helpers, except: [static_path: 2]

      import Explorer.Chain.CurrencyHelper, only: [divide_decimals: 2]

      import BlockScoutWeb.Routers.WebRouter.Helpers, except: [static_path: 2]

      import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]
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

      use Gettext, backend: BlockScoutWeb.Gettext

      import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]
      import BlockScoutWeb.AccessHelper, only: [valid_address_hash_and_not_restricted_access?: 1]
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
