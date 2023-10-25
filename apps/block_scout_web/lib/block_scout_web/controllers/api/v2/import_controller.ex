defmodule BlockScoutWeb.API.V2.ImportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Token

  require Logger
  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def import_token_info(
        conn,
        %{
          "iconUrl" => icon_url,
          "tokenAddress" => token_address_hash_string,
          "tokenSymbol" => token_symbol,
          "tokenName" => token_name
        } = params
      ) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:format_address, {:ok, address_hash}} <-
           {:format_address, Chain.string_to_address_hash(token_address_hash_string)},
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      changeset =
        %{is_verified_via_admin_panel: true}
        |> put_icon_url(icon_url)
        |> put_token_string_field(token_symbol, :symbol)
        |> put_token_string_field(token_name, :name)

      case token |> Token.changeset(changeset) |> Repo.update() do
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

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme != nil && uri.host =~ "."
  end

  defp valid_url?(_url), do: false

  defp put_icon_url(changeset, icon_url) do
    if valid_url?(icon_url) do
      Map.put(changeset, :icon_url, icon_url)
    else
      changeset
    end
  end

  defp put_token_string_field(changeset, token_symbol, field) when is_binary(token_symbol) do
    token_symbol = String.trim(token_symbol)

    if token_symbol !== "" do
      Map.put(changeset, field, token_symbol)
    else
      changeset
    end
  end

  defp put_token_string_field(changeset, _token_symbol, _field), do: changeset
end
