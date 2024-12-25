defmodule BlockScoutWeb.Routers.AccountRouter do
  @moduledoc """
  Router for account-related requests
  """
  use BlockScoutWeb, :router

  alias BlockScoutWeb.Account.API.V2.{
    AddressController,
    AuthenticateController,
    EmailController,
    TagsController,
    UserController
  }

  alias BlockScoutWeb.Plug.{CheckAccountAPI, CheckAccountWeb}

  @max_query_string_length 5_000

  pipeline :account_web do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 100_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :block_scout_web)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(CheckAccountWeb)
    plug(:protect_from_forgery)
    plug(BlockScoutWeb.CSPHeader)
    plug(BlockScoutWeb.ChecksumAddress)
  end

  pipeline :account_api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 100_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(CheckAccountAPI)
  end

  pipeline :api do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      length: 20_000_000,
      query_string_length: @max_query_string_length,
      pass: ["*/*"],
      json_decoder: Poison
    )

    plug(BlockScoutWeb.Plug.Logger, application: :api)
    plug(:accepts, ["json"])
  end

  scope "/auth", BlockScoutWeb do
    pipe_through(:account_web)

    get("/profile", Account.AuthController, :profile)
    get("/logout", Account.AuthController, :logout)
    get("/:provider", Account.AuthController, :request)
    get("/:provider/callback", Account.AuthController, :callback)
  end

  scope "/", BlockScoutWeb do
    pipe_through(:account_web)

    resources("/tag_address", Account.TagAddressController,
      only: [:index, :new, :create, :delete],
      as: :tag_address
    )

    resources("/tag_transaction", Account.TagTransactionController,
      only: [:index, :new, :create, :delete],
      as: :tag_transaction
    )

    resources("/watchlist", Account.WatchlistController,
      only: [:show],
      singleton: true,
      as: :watchlist
    )

    resources("/watchlist_address", Account.WatchlistAddressController,
      only: [:new, :create, :edit, :update, :delete],
      as: :watchlist_address
    )

    resources("/api_key", Account.ApiKeyController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :api_key
    )

    resources("/custom_abi", Account.CustomABIController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :custom_abi
    )

    resources("/public_tags_request", Account.PublicTagsRequestController,
      only: [:new, :create, :edit, :update, :delete, :index],
      as: :public_tags_request
    )
  end

  scope "/v2", as: :account_v2 do
    pipe_through(:account_api)

    get("/authenticate", AuthenticateController, :authenticate_get)
    post("/authenticate", AuthenticateController, :authenticate_post)

    get("/get_csrf", UserController, :get_csrf)

    scope "/address" do
      post("/link", AddressController, :link_address)
    end

    scope "/email" do
      get("/resend", EmailController, :resend_email)
      post("/link", EmailController, :link_email)
    end

    scope "/user" do
      get("/info", UserController, :info)

      get("/watchlist", UserController, :watchlist)
      delete("/watchlist/:id", UserController, :delete_watchlist)
      post("/watchlist", UserController, :create_watchlist)
      put("/watchlist/:id", UserController, :update_watchlist)

      get("/api_keys", UserController, :api_keys)
      delete("/api_keys/:api_key", UserController, :delete_api_key)
      post("/api_keys", UserController, :create_api_key)
      put("/api_keys/:api_key", UserController, :update_api_key)

      get("/custom_abis", UserController, :custom_abis)
      delete("/custom_abis/:id", UserController, :delete_custom_abi)
      post("/custom_abis", UserController, :create_custom_abi)
      put("/custom_abis/:id", UserController, :update_custom_abi)

      get("/public_tags", UserController, :public_tags_requests)
      delete("/public_tags/:id", UserController, :delete_public_tags_request)
      post("/public_tags", UserController, :create_public_tags_request)
      put("/public_tags/:id", UserController, :update_public_tags_request)

      scope "/tags" do
        get("/address/", UserController, :tags_address)
        get("/address/:id", UserController, :tags_address)
        delete("/address/:id", UserController, :delete_tag_address)
        post("/address/", UserController, :create_tag_address)
        put("/address/:id", UserController, :update_tag_address)

        get("/transaction/", UserController, :tags_transaction)
        get("/transaction/:id", UserController, :tags_transaction)
        delete("/transaction/:id", UserController, :delete_tag_transaction)
        post("/transaction/", UserController, :create_tag_transaction)
        put("/transaction/:id", UserController, :update_tag_transaction)
      end
    end
  end

  scope "/v2" do
    pipe_through(:api)
    pipe_through(:account_api)

    scope "/tags" do
      get("/address/:address_hash", TagsController, :tags_address)

      get("/transaction/:transaction_hash", TagsController, :tags_transaction)
    end
  end

  scope "/v2" do
    pipe_through(:api)

    post("/authenticate_via_wallet", AuthenticateController, :authenticate_via_wallet)
    post("/send_otp", AuthenticateController, :send_otp)
    post("/confirm_otp", AuthenticateController, :confirm_otp)
    get("/siwe_message", AuthenticateController, :siwe_message)
  end
end
