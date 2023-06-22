defmodule BlockScoutWeb.API.V2.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      token_transfers_next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1,
      current_filter: 1
    ]

  import BlockScoutWeb.PagingHelper,
    only: [delete_parameters_from_next_page_params: 1, token_transfers_types_options: 1]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.API.V2.{BlockView, TransactionView, WithdrawalView}
  alias Explorer.{Chain, Market}
  alias Indexer.Fetcher.{CoinBalanceOnDemand, TokenBalanceOnDemand}

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      :block => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    },
    api?: true
  ]

  @token_transfer_necessity_by_association [
    necessity_by_association: %{
      :to_address => :optional,
      :from_address => :optional,
      :block => :optional,
      :transaction => :optional
    },
    api?: true
  ]

  @address_options [
    necessity_by_association: %{
      :contracts_creation_internal_transaction => :optional,
      :names => :optional,
      :smart_contract => :optional,
      :token => :optional,
      :contracts_creation_transaction => :optional
    },
    api?: true
  ]

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def address(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <- {:not_found, Chain.hash_to_address(address_hash, @address_options)} do
      CoinBalanceOnDemand.trigger_fetch(address)

      conn
      |> put_status(200)
      |> render(:address, %{address: address})
    end
  end

  def counters(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      {validation_count} = Chain.address_counters(address, @api_true)

      transactions_from_db = address.transactions_count || 0
      token_transfers_from_db = address.token_transfers_count || 0
      address_gas_usage_from_db = address.gas_used || 0

      json(conn, %{
        transactions_count: to_string(transactions_from_db),
        token_transfers_count: to_string(token_transfers_from_db),
        gas_usage_count: to_string(address_gas_usage_from_db),
        validations_count: to_string(validation_count)
      })
    end
  end

  def token_balances(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      token_balances =
        address_hash
        |> Chain.fetch_last_token_balances(@api_true)

      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash, token_balances)
      end)

      conn
      |> put_status(200)
      |> render(:token_balances, %{token_balances: token_balances})
    end
  end

  def transactions(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      options =
        @transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      results_plus_one = Chain.address_to_transactions_without_rewards(address_hash, options, false)
      {transactions, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(transactions, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{transactions: transactions, next_page_params: next_page_params})
    end
  end

  def token_transfers(
        conn,
        %{"address_hash" => address_hash_string, "token" => token_address_hash_string} = params
      ) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:format, {:ok, token_address_hash}} <- {:format, Chain.string_to_address_hash(token_address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:ok, false} <- AccessHelper.restricted_access?(token_address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)},
         {:not_found, {:ok, _}} <- {:not_found, Chain.token_from_address_hash(token_address_hash, @api_true)} do
      paging_options = paging_options(params)

      options =
        [
          necessity_by_association: %{
            :to_address => :optional,
            :from_address => :optional,
            :block => :optional,
            :token => :optional,
            :transaction => :optional
          }
        ]
        |> Keyword.merge(paging_options)
        |> Keyword.merge(@api_true)

      results =
        address_hash
        |> Chain.address_hash_to_token_transfers_by_token_address_hash(
          token_address_hash,
          options
        )
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

  def token_transfers(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      paging_options = paging_options(params)

      options =
        @token_transfer_necessity_by_association
        |> Keyword.merge(paging_options)
        |> Keyword.merge(current_filter(params))
        |> Keyword.merge(token_transfers_types_options(params))

      results =
        address_hash
        |> Chain.address_hash_to_token_transfers_new(options)
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

  def internal_transactions(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      full_options =
        [
          necessity_by_association: %{
            [created_contract_address: :names] => :optional,
            [from_address: :names] => :optional,
            [to_address: :names] => :optional,
            [created_contract_address: :smart_contract] => :optional,
            [from_address: :smart_contract] => :optional,
            [to_address: :smart_contract] => :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))
        |> Keyword.merge(@api_true)

      results_plus_one = Chain.address_to_internal_transactions(address_hash, full_options)
      {internal_transactions, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(internal_transactions, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      })
    end
  end

  def logs(conn, %{"address_hash" => address_hash_string, "topic" => topic} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      prepared_topic = String.trim(topic)

      formatted_topic = if String.starts_with?(prepared_topic, "0x"), do: prepared_topic, else: "0x" <> prepared_topic

      options = params |> paging_options() |> Keyword.merge(topic: formatted_topic) |> Keyword.merge(@api_true)

      results_plus_one = Chain.address_to_logs(address_hash, options)

      {logs, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page |> next_page_params(logs, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:logs, %{logs: logs, next_page_params: next_page_params})
    end
  end

  def logs(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      options = params |> paging_options() |> Keyword.merge(@api_true)

      results_plus_one = Chain.address_to_logs(address_hash, options)

      {logs, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page |> next_page_params(logs, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:logs, %{logs: logs, next_page_params: next_page_params})
    end
  end

  def blocks_validated(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      full_options =
        [
          necessity_by_association: %{
            miner: :required,
            nephews: :optional,
            transactions: :optional,
            rewards: :optional
          }
        ]
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      results_plus_one = Chain.get_blocks_validated_by_address(full_options, address_hash)
      {blocks, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page |> next_page_params(blocks, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(BlockView)
      |> render(:blocks, %{blocks: blocks, next_page_params: next_page_params})
    end
  end

  def coin_balance_history(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      full_options = params |> paging_options() |> Keyword.merge(@api_true)

      results_plus_one = Chain.address_to_coin_balances(address, full_options)

      {coin_balances, next_page} = split_list_by_page(results_plus_one)

      next_page_params =
        next_page |> next_page_params(coin_balances, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:coin_balances, %{coin_balances: coin_balances, next_page_params: next_page_params})
    end
  end

  def coin_balance_history_by_day(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      balances_by_day =
        address_hash
        |> Chain.address_to_balances_by_day(@api_true)

      conn
      |> put_status(200)
      |> render(:coin_balances_by_day, %{coin_balances_by_day: balances_by_day})
    end
  end

  def tokens(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      results_plus_one =
        address_hash
        |> Chain.fetch_paginated_last_token_balances(
          params
          |> delete_parameters_from_next_page_params()
          |> paging_options()
          |> Keyword.merge(token_transfers_types_options(params))
          |> Keyword.merge(@api_true)
        )

      Task.start_link(fn ->
        TokenBalanceOnDemand.trigger_fetch(address_hash, results_plus_one)
      end)

      {tokens, next_page} = split_list_by_page(results_plus_one)

      next_page_params = next_page |> next_page_params(tokens, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> render(:tokens, %{tokens: tokens, next_page_params: next_page_params})
    end
  end

  def withdrawals(conn, %{"address_hash" => address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, _address}} <- {:not_found, Chain.hash_to_address(address_hash, @api_true, false)} do
      options = @api_true |> Keyword.merge(paging_options(params))
      withdrawals_plus_one = address_hash |> Chain.address_hash_to_withdrawals(options)
      {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

      next_page_params = next_page |> next_page_params(withdrawals, params) |> delete_parameters_from_next_page_params()

      conn
      |> put_status(200)
      |> put_view(WithdrawalView)
      |> render(:withdrawals, %{withdrawals: withdrawals, next_page_params: next_page_params})
    end
  end

  def addresses_list(conn, params) do
    {addresses, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Chain.list_top_addresses()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, addresses, params)

    exchange_rate = Market.get_coin_exchange_rate()
    total_supply = Chain.total_supply()

    conn
    |> put_status(200)
    |> render(:addresses, %{
      addresses: addresses,
      next_page_params: next_page_params,
      exchange_rate: exchange_rate,
      total_supply: total_supply
    })
  end
end
