defmodule BlockScoutWeb.API.V2.TokenController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.{Chain, Market}

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3,
      unique_tokens_paging_options: 1,
      unique_tokens_next_page: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [delete_parameters_from_next_page_params: 1, token_transfers_types_options: 1]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def token(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash)} do
      conn
      |> put_status(200)
      |> render(:token, %{token: Market.add_price(token)})
    end
  end

  def counters(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _}} <- {:not_found, Chain.token_from_address_hash(address_hash)} do
      {transfer_count, token_holder_count} = Chain.fetch_token_counters(address_hash, 30_000)

      json(conn, %{transfers_count: to_string(transfer_count), token_holders_count: to_string(token_holder_count)})
    end
  end

  def transfers(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _}} <- {:not_found, Chain.token_from_address_hash(address_hash)} do
      results_plus_one = Chain.fetch_token_transfers_from_token_hash(address_hash, paging_options(params))

      {token_transfers, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(token_transfers, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def holders(conn, %{"address_hash" => address_hash_string} = params) do
    from_api = true

    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash)} do
      results_plus_one = Chain.fetch_token_holders_from_token_hash(address_hash, from_api, paging_options(params))
      {token_balances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(token_balances, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_balances, %{token_balances: token_balances, next_page_params: next_page_params, token: token})
    end
  end

  def instances(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash)} do
      results_plus_one =
        Chain.address_to_unique_tokens(token.contract_address_hash, unique_tokens_paging_options(params))

      {token_instances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> unique_tokens_next_page(token_instances, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_instances, %{token_instances: token_instances, next_page_params: next_page_params, token: token})
    end
  end

  def instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash)},
         {:not_found, {:ok, token_instance}} <-
           {:not_found, Chain.erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, address_hash)} do
      conn
      |> put_status(200)
      |> render(:token_instance, %{token_instance: token_instance |> Chain.put_owner_to_token_instance(), token: token})
    end
  end

  def transfers_by_instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _token}} <- {:not_found, Chain.token_from_address_hash(address_hash)},
         {:not_found, {:ok, _token_instance}} <-
           {:not_found, Chain.erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, address_hash)} do
      results_plus_one =
        Chain.fetch_token_transfers_from_token_hash_and_token_id(address_hash, token_id, paging_options(params))

      {token_transfers, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(token_transfers, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def transfers_count_by_instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _token}} <- {:not_found, Chain.token_from_address_hash(address_hash)},
         {:not_found, {:ok, _token_instance}} <-
           {:not_found, Chain.erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, address_hash)} do
      conn
      |> put_status(200)
      |> json(%{transfers_count: Chain.count_token_transfers_from_token_hash_and_token_id(address_hash, token_id)})
    end
  end

  def tokens_list(conn, params) do
    filter =
      if Map.has_key?(params, "filter") do
        Map.get(params, "filter")
      else
        nil
      end

    paging_params =
      params
      |> paging_options()
      |> Keyword.merge(token_transfers_types_options(params))

    {tokens, next_page} = filter |> Chain.list_top_tokens(paging_params) |> Market.add_price() |> split_list_by_page()

    next_page_params = next_page |> next_page_params(tokens, params) |> delete_parameters_from_next_page_params()

    conn
    |> put_status(200)
    |> render(:tokens, %{tokens: tokens, next_page_params: next_page_params})
  end
end
