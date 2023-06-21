defmodule BlockScoutWeb.API.V2.TokenController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.TransactionView
  alias Explorer.Chain
  alias Indexer.Fetcher.TokenTotalSupplyOnDemand

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      paging_options: 1,
      next_page_params: 3,
      token_transfers_next_page_params: 3,
      unique_tokens_paging_options: 1,
      unique_tokens_next_page: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [delete_parameters_from_next_page_params: 1, token_transfers_types_options: 1]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @api_true [api?: true]

  def token(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      TokenTotalSupplyOnDemand.trigger_fetch(address_hash)

      conn
      |> put_status(200)
      |> render(:token, %{token: token})
    end
  end

  def counters(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, true} <- {:not_found, Chain.token_from_address_hash_exists?(address_hash, @api_true)} do
      {transfer_count, token_holder_count} = Chain.fetch_token_counters(address_hash, 30_000)

      json(conn, %{transfers_count: to_string(transfer_count), token_holders_count: to_string(token_holder_count)})
    end
  end

  def transfers(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, true} <- {:not_found, Chain.token_from_address_hash_exists?(address_hash, @api_true)} do
      paging_options = paging_options(params)

      results =
        address_hash
        |> Chain.fetch_token_transfers_from_token_hash(Keyword.merge(@api_true, paging_options))
        |> Chain.flat_1155_batch_token_transfers()
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def holders(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      results_plus_one =
        Chain.fetch_token_holders_from_token_hash(address_hash, Keyword.merge(paging_options(params), @api_true))

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
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      results_plus_one =
        Chain.address_to_unique_tokens(
          token.contract_address_hash,
          Keyword.merge(unique_tokens_paging_options(params), @api_true)
        )

      {token_instances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> unique_tokens_next_page(token_instances, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_instances, %{token_instances: token_instances, next_page_params: next_page_params, token: token})
    end
  end

  def instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id_str} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.is_erc_20_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_str)} do
      token_instance =
        case Chain.erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, address_hash, @api_true) do
          {:ok, token_instance} -> token_instance |> Chain.put_owner_to_token_instance(@api_true)
          {:error, :not_found} -> %{token_id: token_id, metadata: nil, owner: nil}
        end

      conn
      |> put_status(200)
      |> render(:token_instance, %{
        token_instance: token_instance,
        token: token
      })
    end
  end

  def transfers_by_instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id_str} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.is_erc_20_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_str)} do
      paging_options = paging_options(params)

      results =
        address_hash
        |> Chain.fetch_token_transfers_from_token_hash_and_token_id(token_id, Keyword.merge(paging_options, @api_true))
        |> Chain.flat_1155_batch_token_transfers(Decimal.new(token_id))
        |> Chain.paginate_1155_batch_token_transfers(paging_options)

      {token_transfers, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> token_transfers_next_page_params(token_transfers, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:token_transfers, %{token_transfers: token_transfers, next_page_params: next_page_params})
    end
  end

  def holders_by_instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id_str} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.is_erc_20_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_str)} do
      paging_options = paging_options(params)

      results =
        Chain.fetch_token_holders_from_token_hash_and_token_id(
          address_hash,
          token_id,
          Keyword.merge(paging_options, @api_true)
        )

      {token_holders, next_page} = split_list_by_page(results)

      next_page_params =
        next_page
        |> next_page_params(token_holders, params)
        |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:token_balances, %{token_balances: token_holders, next_page_params: next_page_params, token: token})
    end
  end

  def transfers_count_by_instance(conn, %{"address_hash" => address_hash_string, "token_id" => token_id_str} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)},
         {:not_found, false} <- {:not_found, Chain.is_erc_20_token?(token)},
         {:format, {token_id, ""}} <- {:format, Integer.parse(token_id_str)} do
      conn
      |> put_status(200)
      |> json(%{
        transfers_count: Chain.count_token_transfers_from_token_hash_and_token_id(address_hash, token_id, @api_true)
      })
    end
  end

  def tokens_list(conn, params) do
    filter = params["q"]

    options =
      params
      |> paging_options()
      |> Keyword.merge(token_transfers_types_options(params))
      |> Keyword.merge(@api_true)

    {tokens, next_page} = filter |> Chain.list_top_tokens(options) |> split_list_by_page()

    next_page_params = next_page |> next_page_params(tokens, params) |> delete_parameters_from_next_page_params()

    conn
    |> put_status(200)
    |> render(:tokens, %{tokens: tokens, next_page_params: next_page_params})
  end
end
