defmodule BlockScoutWeb.API.RPC.TokenController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.RPC.Helper
  alias Explorer.{Chain, PagingOptions}

  @default_page_size 50

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

  def bridgedtokenlist(conn, params) do
    chainid = params |> Map.get("chainid")
    destination = translate_chain_id_to_destination(chainid)

    params_with_paging_options = Helper.put_pagination_options(%{}, params)

    page_number =
      if Map.has_key?(params_with_paging_options, :page_number), do: params_with_paging_options.page_number, else: 1

    page_size =
      if Map.has_key?(params_with_paging_options, :page_size),
        do: params_with_paging_options.page_size,
        else: @default_page_size

    options = [
      paging_options: %PagingOptions{
        key: nil,
        page_number: page_number,
        page_size: page_size
      }
    ]

    from_api = true
    bridged_tokens = Chain.list_top_bridged_tokens(destination, nil, from_api, options)
    render(conn, "bridgedtokenlist.json", %{bridged_tokens: bridged_tokens})
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp translate_chain_id_to_destination(destination) do
    case destination do
      "1" -> :eth
      "42" -> :kovan
      "56" -> :bsc
      "99" -> :poa
      wrong_chain_id -> wrong_chain_id
    end
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end
end
