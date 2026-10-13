# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TokenController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, bridged_tokens_enabled: [:explorer, [Explorer.Chain.BridgedToken, :enabled]]

  alias BlockScoutWeb.API.RPC.Helper
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Cache.Counters.TokenCounters

  @api_true [api?: true]

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
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param) do
      options = holders_paging_options(params)

      token_holders = Chain.fetch_token_holders_from_token_hash(address_hash, options)
      render(conn, "gettokenholders.json", %{token_holders: token_holders})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")
    end
  end

  @doc """
  Etherscan-compatible `tokenholderlist` action.

  Returns the current token holders ordered by balance (descending) as a list
  of `%{"TokenHolderAddress" => ..., "TokenHolderQuantity" => ...}` maps.
  Supports Etherscan `page`/`offset` pagination.
  """
  @spec tokenholderlist(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tokenholderlist(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param) do
      options = holders_paging_options(params)

      token_holders = Chain.fetch_token_holders_from_token_hash_for_csv(address_hash, options)
      render(conn, "tokenholderlist.json", %{token_holders: token_holders})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")
    end
  end

  @doc """
  Etherscan-compatible `tokenholdercount` action.

  Returns the number of current token holders as a string.
  """
  @spec tokenholdercount(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tokenholdercount(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param),
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash, @api_true)} do
      if is_nil(token.holder_count) do
        TokenCounters.mark_dirty_at_max_block(token.contract_address_hash)
      end

      render(conn, "tokenholdercount.json", %{holder_count: token.holder_count})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "Contract address not found")
    end
  end

  @doc """
  Etherscan-compatible `tokeninfo` action.

  Returns a one-element list with the token's project details in the
  Etherscan `tokeninfo` response shape.
  """
  @spec tokeninfo(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tokeninfo(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param),
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash, @api_true)} do
      render(conn, "tokeninfo.json", %{token: token})
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address hash")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "Contract address not found")
    end
  end

  if @bridged_tokens_enabled do
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

      # credo:disable-for-lines:2 Credo.Check.Design.AliasUsage
      bridged_tokens =
        if Explorer.Chain.BridgedToken.enabled?() do
          options =
            params
            |> paging_options()
            |> Keyword.merge(chain_ids_filter_options(params))
            |> Keyword.merge(tokens_sorting(params))
            |> Keyword.merge(@api_true)

          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          "" |> Explorer.Chain.BridgedToken.list_top_bridged_tokens(options)
        else
          []
        end

      render(conn, "bridgedtokenlist.json", %{bridged_tokens: bridged_tokens})
    end
  end

  # Builds paging options for token holders queries from Etherscan-style
  # `page`/`offset` params, defaulting to the first page of 10 records.
  defp holders_paging_options(params) do
    options_with_defaults =
      %{}
      |> Helper.put_pagination_options(params)
      |> Map.put_new(:page_number, 1)
      |> Map.put_new(:page_size, 10)

    [
      paging_options: %PagingOptions{
        key: nil,
        page_number: options_with_defaults.page_number,
        page_size: options_with_defaults.page_size
      }
    ] ++ @api_true
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end
end
