defmodule BlockScoutWeb.API.V2.ImportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Token

  require Logger
  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def import_token_info(conn, %{"iconUrl" => icon_url, "tokenAddress" => token_address_hash_string} = params) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(token_address_hash_string)},
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      case token |> Token.changeset(%{icon_url: icon_url}) |> Repo.update() do
        {:ok, _} ->
          conn
          |> put_view(ApiView)
          |> render(:message, %{message: "Success"})

        error ->
          Logger.warn(fn -> ["Error on importing token info: ", inspect(error)] end)

          conn
          |> put_view(ApiView)
          |> put_status(:bad_request)
          |> render(:message, %{message: "Error"})
      end
    end
  end
end
