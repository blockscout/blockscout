defmodule BlockScoutWeb.API.RPC.TokenController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]

  alias BlockScoutWeb.API.RPC.Helper
  alias Explorer.{Chain, PagingOptions}

  def gettoken(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param),
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash)} do
      render(conn, "gettoken.json", %{token: token})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "Contract address not found")
    end
  end

  def gettokenholders(conn, params) do
    with pagination_options <- Helper.put_pagination_options(%{}, params),
         {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param) do
      options_with_defaults =
        pagination_options
        |> Map.put_new(:page_number, 0)
        |> Map.put_new(:page_size, 10)

      options = [
        paging_options: %PagingOptions{
          key: nil,
          page_number: options_with_defaults.page_number,
          page_size: options_with_defaults.page_size
        },
        api?: true
      ]

      token_holders = Chain.fetch_token_holders_from_token_hash(address_hash, options)
      render(conn, "gettokenholders.json", %{token_holders: token_holders})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")
    end
  end

  if @bridged_tokens_enabled do
    @api_true [api?: true]
    def bridgedtokenlist(conn, params) do
      import BlockScoutWeb.PagingHelper,
        only: [
          chain_ids_filter_options: 1,
          tokens_sorting: 1
        ]

      import BlockScoutWeb.Chain,
        only: [
          paging_options: 1
        ]

      bridged_tokens =
        if BridgedToken.enabled?() do
          options =
            params
            |> paging_options()
            |> Keyword.merge(chain_ids_filter_options(params))
            |> Keyword.merge(tokens_sorting(params))
            |> Keyword.merge(@api_true)

          "" |> BridgedToken.list_top_bridged_tokens(options)
        else
          []
        end

      render(conn, "bridgedtokenlist.json", %{bridged_tokens: bridged_tokens})
    end
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end
end
