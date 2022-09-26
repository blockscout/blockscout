defmodule BlockScoutWeb.API.V2.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper}
  alias BlockScoutWeb.{ABIEncodedValueView, TransactionView}
  alias BlockScoutWeb.Tokens.Helpers
  alias Explorer.ExchangeRates.Token
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Block, InternalTransaction, Log, Transaction, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias Timex.Duration

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("transactions.json", %{transactions: transactions, next_page_params: next_page_params}) do
    %{"items" => Enum.map(transactions, &prepare_transaction/1), "next_page_params" => next_page_params}
  end

  def render("transaction.json", %{transaction: transaction}) do
    prepare_transaction(transaction)
  end

  def render("raw_trace.json", %{internal_transactions: internal_transactions}) do
    InternalTransaction.internal_transactions_to_raw(internal_transactions)
  end

  def render("decoded_log_input.json", %{method_id: method_id, text: text, mapping: mapping}) do
    %{"method_id" => method_id, "method_call" => text, "parameters" => prepare_log_mapping(mapping)}
  end

  def render("decoded_input.json", %{method_id: method_id, text: text, mapping: mapping, error?: _error}) do
    %{"method_id" => method_id, "method_call" => text, "parameters" => prepare_method_mapping(mapping)}
  end

  def render("revert_reason.json", %{raw: raw, decoded: decoded}) do
    %{"raw" => raw, "decoded" => decoded}
  end

  def render("token_transfers.json", %{token_transfers: token_transfers, next_page_params: next_page_params}) do
    %{"items" => Enum.map(token_transfers, &prepare_token_transfer/1), "next_page_params" => next_page_params}
  end

  def render("token_transfers.json", %{token_transfers: token_transfers}) do
    Enum.map(token_transfers, &prepare_token_transfer/1)
  end

  def render("token_transfer.json", %{token_transfer: token_transfer}) do
    prepare_token_transfer(token_transfer)
  end

  def render("internal_transactions.json", %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(internal_transactions, &prepare_internal_transaction/1),
      "next_page_params" => next_page_params
    }
  end

  def render("logs.json", %{logs: logs, next_page_params: next_page_params, tx_hash: tx_hash}) do
    %{"items" => Enum.map(logs, fn log -> prepare_log(log, tx_hash) end), "next_page_params" => next_page_params}
  end

  def prepare_token_transfer(token_transfer) do
    %{
      "tx_hash" => token_transfer.transaction_hash,
      "from" => Helper.address_with_info(token_transfer.from_address, token_transfer.from_address_hash),
      "to" => Helper.address_with_info(token_transfer.to_address, token_transfer.to_address_hash),
      "total" => prepare_token_transfer_total(token_transfer),
      "token_address" => token_transfer.token_contract_address_hash,
      "token_symbol" => Helpers.token_symbol(token_transfer.token),
      "type" => Chain.get_token_transfer_type(token_transfer),
      "token_type" => token_transfer.token.type,
      "exchange_rate" => Market.add_price(token_transfer.token).usd_value
    }
  end

  def prepare_token_transfer_total(token_transfer) do
    case Helpers.token_transfer_amount(token_transfer) do
      {:ok, :erc721_instance} ->
        %{"token_id" => token_transfer.token_id}

      {:ok, :erc1155_instance, value} ->
        %{"token_id" => token_transfer.token_id, "value" => value}

      {:ok, :erc1155_instance, values, token_ids, _decimals} ->
        Enum.map(Enum.zip(values, token_ids), fn {value, token_id} -> %{"value" => value, "token_id" => token_id} end)

      {:ok, value} ->
        %{"value" => value}
    end
  end

  def prepare_internal_transaction(internal_transaction) do
    %{
      "error" => internal_transaction.error,
      "success" => is_nil(internal_transaction.error),
      "type" => internal_transaction.call_type,
      "transaction_hash" => internal_transaction.transaction_hash,
      "from" => Helper.address_with_info(internal_transaction.from_address, internal_transaction.from_address_hash),
      "to" => Helper.address_with_info(internal_transaction.to_address, internal_transaction.to_address_hash),
      "created_contract" =>
        Helper.address_with_info(
          internal_transaction.created_contract_address,
          internal_transaction.created_contract_address_hash
        ),
      "value" => internal_transaction.value,
      "block" => internal_transaction.block_number,
      "timestamp" => internal_transaction.transaction.block.timestamp,
      "index" => internal_transaction.index
    }
  end

  def prepare_log(log, transaction_hash) do
    decoded =
      case log |> Log.decode(%Transaction{hash: transaction_hash}) |> format_decoded_log_input() do
        {:ok, method_id, text, mapping} ->
          render(__MODULE__, "decoded_log_input.json", method_id: method_id, text: text, mapping: mapping)

        _ ->
          nil
      end

    %{
      "address" => Helper.address_with_info(log.address, log.address_hash),
      "topics" => [
        log.first_topic,
        log.second_topic,
        log.third_topic,
        log.fourth_topic
      ],
      "data" => log.data,
      "index" => log.index,
      "decoded" => decoded
    }
  end

  defp prepare_transaction(transaction) do
    base_fee_per_gas = transaction.block && transaction.block.base_fee_per_gas
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas
    max_fee_per_gas = transaction.max_fee_per_gas

    priority_fee_per_gas = priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas)

    burned_fee = burned_fee(transaction, max_fee_per_gas, base_fee_per_gas)

    status = transaction |> Chain.transaction_to_status() |> format_status()

    revert_reason = revert_reason(status, transaction)

    decoded_input_data = decoded_input(transaction)

    %{
      "hash" => transaction.hash,
      "result" => status,
      "status" => transaction.status,
      "block" => transaction.block_number,
      "timestamp" => transaction.block && transaction.block.timestamp,
      "from" => Helper.address_with_info(transaction.from_address, transaction.from_address_hash),
      "to" => Helper.address_with_info(transaction.to_address, transaction.to_address_hash),
      "created_contract" =>
        Helper.address_with_info(transaction.created_contract_address, transaction.created_contract_address_hash),
      "confirmations" =>
        transaction.block |> Chain.confirmations(block_height: Chain.block_height()) |> format_confirmations(),
      "confirmation_duration" => processing_time_duration(transaction),
      "value" => transaction.value,
      "fee" => transaction |> Chain.fee(:wei) |> format_fee(),
      "gas_price" => transaction.gas_price,
      "type" => transaction.type,
      "gas_used" => transaction.gas_used,
      "gas_limit" => transaction.gas,
      "max_fee_per_gas" => transaction.max_fee_per_gas,
      "max_priority_fee_per_gas" => transaction.max_priority_fee_per_gas,
      "base_fee_per_gas" => base_fee_per_gas,
      "priority_fee" => priority_fee_per_gas && Wei.mult(priority_fee_per_gas, transaction.gas_used),
      "tx_burnt_fee" => burned_fee,
      "nonce" => transaction.nonce,
      "position" => transaction.index,
      "revert_reason" => revert_reason,
      "raw_input" => transaction.input,
      "decoded_input" => decoded_input_data,
      "token_transfers" =>
        render("token_transfers.json", %{
          token_transfers:
            Enum.take(transaction.token_transfers, Chain.get_token_transfers_per_transaction_preview_count())
        }),
      "token_transfers_overflow" =>
        Enum.count(transaction.token_transfers) > Chain.get_token_transfers_per_transaction_preview_count(),
      "exchange_rate" => (Market.get_exchange_rate(Explorer.coin()) || Token.null()).usd_value
    }
  end

  defp priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas) do
    if is_nil(max_priority_fee_per_gas) or is_nil(base_fee_per_gas),
      do: nil,
      else:
        Enum.min_by([max_priority_fee_per_gas, Wei.sub(max_fee_per_gas, base_fee_per_gas)], fn x ->
          Wei.to(x, :wei)
        end)
  end

  defp burned_fee(transaction, max_fee_per_gas, base_fee_per_gas) do
    if !is_nil(max_fee_per_gas) and !is_nil(transaction.gas_used) and !is_nil(base_fee_per_gas) do
      if Decimal.compare(max_fee_per_gas.value, 0) == :eq do
        %Wei{value: Decimal.new(0)}
      else
        Wei.mult(base_fee_per_gas, transaction.gas_used)
      end
    else
      nil
    end
  end

  defp revert_reason(status, transaction) do
    if is_binary(status) && status |> String.downcase() |> String.contains?("reverted") do
      case TransactionView.transaction_revert_reason(transaction) do
        {:error, _contract_not_verified, candidates} when candidates != [] ->
          {:ok, method_id, text, mapping} = Enum.at(candidates, 0)
          render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

        {:ok, method_id, text, mapping} ->
          render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

        _ ->
          hex = TransactionView.get_pure_transaction_revert_reason(transaction)
          utf8 = TransactionView.decoded_revert_reason(transaction)
          render(__MODULE__, "revert_reason.json", raw: hex, decoded: utf8)
      end
    end
  end

  defp decoded_input(transaction) do
    case transaction |> Transaction.decoded_input_data() |> format_decoded_input() do
      {:ok, method_id, text, mapping} ->
        render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: false)

      _ ->
        nil
    end
  end

  def prepare_method_mapping(mapping) do
    Enum.map(mapping, fn {name, type, value} ->
      %{"name" => name, "type" => type, "value" => ABIEncodedValueView.value_json(type, value)}
    end)
  end

  def prepare_log_mapping(mapping) do
    Enum.map(mapping, fn {name, type, indexed?, value} ->
      %{"name" => name, "type" => type, "indexed" => indexed?, "value" => ABIEncodedValueView.value_json(type, value)}
    end)
  end

  defp format_status({:error, reason}), do: reason
  defp format_status(status), do: status

  defp format_decoded_input({:error, _, []}), do: nil
  defp format_decoded_input({:error, _, candidates}), do: Enum.at(candidates, 0)
  defp format_decoded_input({:ok, _identifier, _text, _mapping} = decoded), do: decoded
  defp format_decoded_input(_), do: nil

  defp format_decoded_log_input({:error, :could_not_decode}), do: nil
  defp format_decoded_log_input({:error, :no_matching_function}), do: nil
  defp format_decoded_log_input({:ok, _method_id, _text, _mapping} = decoded), do: decoded
  defp format_decoded_log_input({:error, _, candidates}), do: Enum.at(candidates, 0)

  def format_confirmations({:ok, confirmations}), do: confirmations
  def format_confirmations(_), do: 0

  def format_fee({type, value}), do: %{"type" => type, "value" => value}

  def processing_time_duration(%Transaction{block: nil}) do
    []
  end

  def processing_time_duration(%Transaction{earliest_processing_start: nil}) do
    avg_time = AverageBlockTime.average_block_time()

    if avg_time == {:error, :disabled} do
      []
    else
      [
        0,
        avg_time
        |> Duration.to_milliseconds()
      ]
    end
  end

  def processing_time_duration(%Transaction{
        block: %Block{timestamp: end_time},
        earliest_processing_start: earliest_processing_start,
        inserted_at: inserted_at
      }) do
    long_interval = diff(earliest_processing_start, end_time)
    short_interval = diff(inserted_at, end_time)
    merge_intervals(short_interval, long_interval)
  end

  def merge_intervals(short, long) when short == long, do: [short]

  def merge_intervals(short, long) do
    [short, long]
  end

  def diff(left, right) do
    left
    |> Timex.diff(right, :milliseconds)
  end
end
