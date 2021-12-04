defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, AddressView, Controller, CurrencyHelpers}
  alias Explorer.Counters.{AddressTokenTransfersCounter, AddressTransactionsCounter, AddressTransactionsGasUsageCounter}
  alias Explorer.{Chain, CustomContractsHelpers, Market}
  alias Explorer.ExchangeRates.Token
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

  def show(conn, %{"id" => id}) do
    redirect(conn, to: AccessHelpers.get_path(conn, :address_transaction_path, :index, id))
  end

  def address_counters(conn, %{"id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      {transaction_count, token_transfer_count, gas_usage_count, validation_count, crc_total_worth} =
        address_counters(address)

      address_gas_usage_count_from_cache = gas_usage_count || 0
      address_gas_usage_from_db = address.gas_used || 0

      gas_usage_count_formatted =
        if address_gas_usage_count_from_cache > 0,
          do: address_gas_usage_count_from_cache,
          else: address_gas_usage_from_db

      json(conn, %{
        transaction_count: transaction_count,
        token_transfer_count: token_transfer_count,
        gas_usage_count: gas_usage_count_formatted,
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
    transaction_count_task =
      Task.async(fn ->
        transaction_count(address)
      end)

    token_transfer_count_task =
      Task.async(fn ->
        token_transfers_count(address)
      end)

    gas_usage_count_task =
      Task.async(fn ->
        gas_usage_count(address)
      end)

    validation_count_task =
      Task.async(fn ->
        validation_count(address)
      end)

    crc_total_worth_task =
      Task.async(fn ->
        crc_total_worth(address)
      end)

    [
      transaction_count_task,
      token_transfer_count_task,
      gas_usage_count_task,
      validation_count_task,
      crc_total_worth_task
    ]
    |> Task.yield_many(:timer.seconds(60))
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
