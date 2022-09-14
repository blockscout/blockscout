defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{
    AccessHelpers,
    AddressTransactionController,
    AddressView,
    Controller,
    CurrencyHelpers
  }

  alias Explorer.Counters.{AddressTokenTransfersCounter, AddressTransactionsCounter, AddressTransactionsGasUsageCounter}
  alias Explorer.{Chain, CustomContractsHelpers, Market}
  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    addresses =
      params
      |> paging_options()
      |> Chain.list_top_addresses()

    {addresses_page, next_page} = split_list_by_page(addresses)

    next_page_path =
      case next_page_params(next_page, addresses_page, params) do
        nil ->
          nil

        next_page_params ->
          address_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
      end

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()
    total_supply = Chain.total_supply()

    items_count_str = Map.get(params, "items_count")

    items_count =
      if items_count_str do
        {items_count, _} = Integer.parse(items_count_str)
        items_count
      else
        0
      end

    items =
      addresses_page
      |> Enum.with_index(1)
      |> Enum.map(fn {{address, tx_count}, index} ->
        View.render_to_string(
          AddressView,
          "_tile.html",
          address: address,
          index: items_count + index,
          exchange_rate: exchange_rate,
          total_supply: total_supply,
          tx_count: tx_count
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  def index(conn, _params) do
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      address_count: Chain.address_estimated_count(),
      total_supply: total_supply
    )
  end

  def show(conn, %{"id" => address_hash_string, "type" => "JSON"} = params) do
    AddressTransactionController.index(conn, Map.put(params, "address_id", address_hash_string))
  end

  def show(conn, %{"id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "_show_address_transactions.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        current_path: Controller.current_full_path(conn),
        tags: get_address_tags(address_hash, current_user(conn))
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

        address = %Chain.Address{
          hash: address_hash,
          smart_contract: nil,
          token: nil,
          fetched_coin_balance: %Wei{value: Decimal.new(0)}
        }

        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            render(
              conn,
              "_show_address_transactions.html",
              address: address,
              coin_balance_status: nil,
              exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
              filter: params["filter"],
              counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
              current_path: Controller.current_full_path(conn),
              tags: get_address_tags(address_hash, current_user(conn))
            )

          _ ->
            not_found(conn)
        end
    end
  end

  def address_counters(conn, %{"id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      {validation_count, crc_total_worth} = address_counters(address)

      transactions_from_db = address.transactions_count || 0
      token_transfers_from_db = address.token_transfers_count || 0
      address_gas_usage_from_db = address.gas_used || 0

      json(conn, %{
        transaction_count: transactions_from_db,
        token_transfer_count: token_transfers_from_db,
        gas_usage_count: address_gas_usage_from_db,
        validation_count: validation_count,
        crc_total_worth: crc_total_worth
      })
    else
      _ ->
        json(conn, %{
          transaction_count: 0,
          token_transfer_count: 0,
          gas_usage_count: 0,
          validation_count: 0,
          crc_total_worth: 0
        })
    end
  end

  defp address_counters(address) do
    validation_count_task =
      Task.async(fn ->
        validation_count(address)
      end)

    crc_total_worth_task =
      Task.async(fn ->
        crc_total_worth(address)
      end)

    Task.start_link(fn ->
      transaction_count(address)
    end)

    Task.start_link(fn ->
      token_transfers_count(address)
    end)

    Task.start_link(fn ->
      gas_usage_count(address)
    end)

    [
      validation_count_task,
      crc_total_worth_task
    ]
    |> Task.yield_many(:infinity)
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching address counters terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching address counters timed out."
      end
    end)
    |> List.to_tuple()
  end

  def transaction_count(address) do
    AddressTransactionsCounter.fetch(address)
  end

  def token_transfers_count(address) do
    AddressTokenTransfersCounter.fetch(address)
  end

  def gas_usage_count(address) do
    AddressTransactionsGasUsageCounter.fetch(address)
  end

  defp validation_count(address) do
    Chain.address_to_validation_count(address.hash)
  end

  defp crc_total_worth(address) do
    circles_total_balance(address.hash)
  end

  defp circles_total_balance(address_hash) do
    circles_addresses_list = CustomContractsHelpers.get_custom_addresses_list(:circles_addresses)

    token_balances =
      address_hash
      |> Chain.fetch_last_token_balances()

    token_balances_except_bridged =
      token_balances
      |> Enum.filter(fn {_, _, token} -> !token.bridged end)

    circles_total_balance_raw =
      if Enum.count(circles_addresses_list) > 0 do
        token_balances_except_bridged
        |> Enum.reduce(Decimal.new(0), fn {token_balance, _, token}, acc_balance ->
          {:ok, token_address} = Chain.hash_to_address(token.contract_address_hash)

          from_address = AddressView.from_address_hash(token_address)

          created_from_address_hash =
            if from_address,
              do: "0x" <> Base.encode16(from_address.bytes, case: :lower),
              else: nil

          if Enum.member?(circles_addresses_list, created_from_address_hash) && token.name == "Circles" &&
               token.symbol == "CRC" do
            Decimal.add(acc_balance, token_balance.value)
          else
            acc_balance
          end
        end)
      else
        Decimal.new(0)
      end

    CurrencyHelpers.format_according_to_decimals(circles_total_balance_raw, Decimal.new(18))
  end
end
