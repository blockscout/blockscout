defmodule BlockScoutWeb.API.V2.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{ApiView, Helper, TokenView}
  alias BlockScoutWeb.{ABIEncodedValueView, TransactionView}
  alias BlockScoutWeb.Models.GetTransactionTags
  alias BlockScoutWeb.Tokens.Helper, as: TokensHelper
  alias BlockScoutWeb.TransactionStateView
  alias Ecto.Association.NotLoaded
  alias Explorer.ExchangeRates.Token, as: TokenRate
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{Address, Block, InternalTransaction, Log, Token, Transaction, Wei}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Transaction.StateChange
  alias Explorer.Counters.AverageBlockTime
  alias Timex.Duration

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  @api_true [api?: true]

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("transactions_watchlist.json", %{
        transactions: transactions,
        next_page_params: next_page_params,
        conn: conn,
        watchlist_names: watchlist_names
      }) do
    %{
      "items" => Enum.map(transactions, &prepare_transaction(&1, conn, false, watchlist_names)),
      "next_page_params" => next_page_params
    }
  end

  def render("transactions_watchlist.json", %{
        transactions: transactions,
        conn: conn,
        watchlist_names: watchlist_names
      }) do
    Enum.map(transactions, &prepare_transaction(&1, conn, false, watchlist_names))
  end

  def render("transactions.json", %{transactions: transactions, next_page_params: next_page_params, conn: conn}) do
    %{"items" => Enum.map(transactions, &prepare_transaction(&1, conn, false)), "next_page_params" => next_page_params}
  end

  def render("transactions.json", %{transactions: transactions, conn: conn}) do
    Enum.map(transactions, &prepare_transaction(&1, conn, false))
  end

  def render("transaction.json", %{transaction: transaction, conn: conn}) do
    prepare_transaction(transaction, conn, true)
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

  def render("revert_reason.json", %{raw: raw}) do
    %{"raw" => raw}
  end

  def render("token_transfers.json", %{token_transfers: token_transfers, next_page_params: next_page_params, conn: conn}) do
    %{"items" => Enum.map(token_transfers, &prepare_token_transfer(&1, conn)), "next_page_params" => next_page_params}
  end

  def render("token_transfers.json", %{token_transfers: token_transfers, conn: conn}) do
    Enum.map(token_transfers, &prepare_token_transfer(&1, conn))
  end

  def render("token_transfer.json", %{token_transfer: token_transfer, conn: conn}) do
    prepare_token_transfer(token_transfer, conn)
  end

  def render("transaction_actions.json", %{actions: actions}) do
    Enum.map(actions, &prepare_transaction_action(&1))
  end

  def render("internal_transactions.json", %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params,
        conn: conn
      }) do
    %{
      "items" => Enum.map(internal_transactions, &prepare_internal_transaction(&1, conn)),
      "next_page_params" => next_page_params
    }
  end

  def render("logs.json", %{logs: logs, next_page_params: next_page_params, tx_hash: tx_hash}) do
    %{"items" => Enum.map(logs, fn log -> prepare_log(log, tx_hash, false) end), "next_page_params" => next_page_params}
  end

  def render("logs.json", %{logs: logs, next_page_params: next_page_params}) do
    %{
      "items" => Enum.map(logs, fn log -> prepare_log(log, log.transaction, true) end),
      "next_page_params" => next_page_params
    }
  end

  def render("state_changes.json", %{state_changes: state_changes}) do
    Enum.map(state_changes, &prepare_state_change(&1))
  end

  def prepare_token_transfer(token_transfer, _conn) do
    decoded_input =
      token_transfer.transaction |> Transaction.decoded_input_data(true, @api_true) |> format_decoded_input()

    %{
      "tx_hash" => token_transfer.transaction_hash,
      "from" => Helper.address_with_info(nil, token_transfer.from_address, token_transfer.from_address_hash),
      "to" => Helper.address_with_info(nil, token_transfer.to_address, token_transfer.to_address_hash),
      "total" => prepare_token_transfer_total(token_transfer),
      "token" => TokenView.render("token.json", %{token: token_transfer.token}),
      "type" => Chain.get_token_transfer_type(token_transfer),
      "timestamp" =>
        if(match?(%NotLoaded{}, token_transfer.block),
          do: block_timestamp(token_transfer.transaction),
          else: block_timestamp(token_transfer.block)
        ),
      "method" => method_name(token_transfer.transaction, decoded_input, true),
      "block_hash" => to_string(token_transfer.block_hash),
      "log_index" => to_string(token_transfer.log_index)
    }
  end

  def prepare_transaction_action(action) do
    %{
      "protocol" => action.protocol,
      "type" => action.type,
      "data" => action.data
    }
  end

  def prepare_token_transfer_total(token_transfer) do
    case TokensHelper.token_transfer_amount_for_api(token_transfer) do
      {:ok, :erc721_instance} ->
        %{"token_id" => List.first(token_transfer.token_ids)}

      {:ok, :erc1155_instance, value, decimals} ->
        %{"token_id" => List.first(token_transfer.token_ids), "value" => value, "decimals" => decimals}

      {:ok, :erc1155_instance, values, token_ids, decimals} ->
        Enum.map(Enum.zip(values, token_ids), fn {value, token_id} ->
          %{"value" => value, "token_id" => token_id, "decimals" => decimals}
        end)

      {:ok, value, decimals} ->
        %{"value" => value, "decimals" => decimals}

      _ ->
        nil
    end
  end

  def prepare_internal_transaction(internal_transaction, _conn) do
    %{
      "error" => internal_transaction.error,
      "success" => is_nil(internal_transaction.error),
      "type" => internal_transaction.call_type || internal_transaction.type,
      "transaction_hash" => internal_transaction.transaction_hash,
      "from" =>
        Helper.address_with_info(nil, internal_transaction.from_address, internal_transaction.from_address_hash),
      "to" => Helper.address_with_info(nil, internal_transaction.to_address, internal_transaction.to_address_hash),
      "created_contract" =>
        Helper.address_with_info(
          nil,
          internal_transaction.created_contract_address,
          internal_transaction.created_contract_address_hash
        ),
      "value" => internal_transaction.value,
      "block" => internal_transaction.block_number,
      "timestamp" => internal_transaction.transaction.block.timestamp,
      "index" => internal_transaction.index,
      "gas_limit" => internal_transaction.gas
    }
  end

  def prepare_log(log, transaction_or_hash, skip_sig_provider?) do
    decoded = decode_log(log, transaction_or_hash, skip_sig_provider?)

    %{
      "tx_hash" => get_tx_hash(transaction_or_hash),
      "address" => Helper.address_with_info(log.address, log.address_hash),
      "topics" => [
        log.first_topic,
        log.second_topic,
        log.third_topic,
        log.fourth_topic
      ],
      "data" => log.data,
      "index" => log.index,
      "decoded" => decoded,
      "smart_contract" => smart_contract_info(transaction_or_hash)
    }
  end

  defp get_tx_hash(%Transaction{} = tx), do: to_string(tx.hash)
  defp get_tx_hash(hash), do: to_string(hash)

  defp smart_contract_info(%Transaction{} = tx), do: Helper.address_with_info(tx.to_address, tx.to_address_hash)
  defp smart_contract_info(_), do: nil

  defp decode_log(log, %Transaction{} = tx, skip_sig_provider?) do
    case log |> Log.decode(tx, @api_true, skip_sig_provider?) |> format_decoded_log_input() do
      {:ok, method_id, text, mapping} ->
        render(__MODULE__, "decoded_log_input.json", method_id: method_id, text: text, mapping: mapping)

      _ ->
        nil
    end
  end

  defp decode_log(log, transaction_hash, skip_sig_provider?),
    do: decode_log(log, %Transaction{hash: transaction_hash}, skip_sig_provider?)

  defp prepare_transaction({%Reward{} = emission_reward, %Reward{} = validator_reward}, conn, single_tx?) do
    %{
      "emission_reward" => emission_reward.reward,
      "block_hash" => validator_reward.block_hash,
      "from" => Helper.address_with_info(single_tx? && conn, emission_reward.address, emission_reward.address_hash),
      "to" => Helper.address_with_info(single_tx? && conn, validator_reward.address, validator_reward.address_hash),
      "types" => [:reward]
    }
  end

  defp prepare_transaction(%Transaction{} = transaction, conn, single_tx?, watchlist_names \\ nil) do
    base_fee_per_gas = transaction.block && transaction.block.base_fee_per_gas
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas
    max_fee_per_gas = transaction.max_fee_per_gas

    priority_fee_per_gas = priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas)

    burned_fee = burned_fee(transaction, max_fee_per_gas, base_fee_per_gas)

    status = transaction |> Chain.transaction_to_status() |> format_status()

    revert_reason = revert_reason(status, transaction)

    decoded_input = transaction |> Transaction.decoded_input_data(!single_tx?, @api_true) |> format_decoded_input()
    decoded_input_data = decoded_input(decoded_input)

    %{
      "hash" => transaction.hash,
      "result" => status,
      "status" => transaction.status,
      "block" => transaction.block_number,
      "timestamp" => block_timestamp(transaction.block),
      "from" =>
        Helper.address_with_info(
          single_tx? && conn,
          transaction.from_address,
          transaction.from_address_hash,
          watchlist_names
        ),
      "to" =>
        Helper.address_with_info(
          single_tx? && conn,
          transaction.to_address,
          transaction.to_address_hash,
          watchlist_names
        ),
      "created_contract" =>
        Helper.address_with_info(
          single_tx? && conn,
          transaction.created_contract_address,
          transaction.created_contract_address_hash,
          watchlist_names
        ),
      "confirmations" =>
        transaction.block |> Chain.confirmations(block_height: Chain.block_height(@api_true)) |> format_confirmations(),
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
      "token_transfers" => token_transfers(transaction.token_transfers, conn, single_tx?),
      "token_transfers_overflow" => token_transfers_overflow(transaction.token_transfers, single_tx?),
      "actions" => transaction_actions(transaction.transaction_actions),
      "exchange_rate" => (Market.get_exchange_rate(Explorer.coin()) || TokenRate.null()).usd_value,
      "method" => method_name(transaction, decoded_input),
      "tx_types" => tx_types(transaction),
      "tx_tag" => GetTransactionTags.get_transaction_tags(transaction.hash, current_user(single_tx? && conn)),
      "has_error_in_internal_txs" => transaction.has_error_in_internal_txs
    }
  end

  def token_transfers(_, _conn, false), do: nil
  def token_transfers(%NotLoaded{}, _conn, _), do: nil

  def token_transfers(token_transfers, conn, _) do
    render("token_transfers.json", %{
      token_transfers: Enum.take(token_transfers, Chain.get_token_transfers_per_transaction_preview_count()),
      conn: conn
    })
  end

  def token_transfers_overflow(_, false), do: nil
  def token_transfers_overflow(%NotLoaded{}, _), do: false

  def token_transfers_overflow(token_transfers, _),
    do: Enum.count(token_transfers) > Chain.get_token_transfers_per_transaction_preview_count()

  defp transaction_actions(%NotLoaded{}), do: []

  defp transaction_actions(actions) do
    render("transaction_actions.json", %{actions: actions})
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
      case TransactionView.transaction_revert_reason(transaction, @api_true) do
        {:error, _contract_not_verified, candidates} when candidates != [] ->
          {:ok, method_id, text, mapping} = Enum.at(candidates, 0)
          render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

        {:ok, method_id, text, mapping} ->
          render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

        _ ->
          hex = TransactionView.get_pure_transaction_revert_reason(transaction)
          render(__MODULE__, "revert_reason.json", raw: hex)
      end
    end
  end

  defp decoded_input(decoded_input) do
    case decoded_input do
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
    long_interval = abs(diff(earliest_processing_start, end_time))
    short_interval = abs(diff(inserted_at, end_time))
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

  defp method_name(_, _, skip_sc_check? \\ false)

  defp method_name(_, {:ok, _method_id, text, _mapping}, _) do
    Transaction.parse_method_name(text, false)
  end

  defp method_name(
         %Transaction{to_address: to_address, input: %{bytes: <<method_id::binary-size(4), _::binary>>}},
         _,
         skip_sc_check?
       ) do
    if skip_sc_check? || Helper.is_smart_contract(to_address) do
      "0x" <> Base.encode16(method_id, case: :lower)
    else
      nil
    end
  end

  defp method_name(_, _, _) do
    nil
  end

  defp tx_types(tx, types \\ [], stage \\ :token_transfer)

  defp tx_types(%Transaction{token_transfers: token_transfers} = tx, types, :token_transfer) do
    types =
      if !is_nil(token_transfers) && token_transfers != [] && !match?(%NotLoaded{}, token_transfers) do
        [:token_transfer | types]
      else
        types
      end

    tx_types(tx, types, :token_creation)
  end

  defp tx_types(%Transaction{created_contract_address: created_contract_address} = tx, types, :token_creation) do
    types =
      if match?(%Address{}, created_contract_address) && match?(%Token{}, created_contract_address.token) do
        [:token_creation | types]
      else
        types
      end

    tx_types(tx, types, :contract_creation)
  end

  defp tx_types(
         %Transaction{to_address_hash: to_address_hash} = tx,
         types,
         :contract_creation
       ) do
    types =
      if is_nil(to_address_hash) do
        [:contract_creation | types]
      else
        types
      end

    tx_types(tx, types, :contract_call)
  end

  defp tx_types(%Transaction{to_address: to_address} = tx, types, :contract_call) do
    types =
      if Helper.is_smart_contract(to_address) do
        [:contract_call | types]
      else
        types
      end

    tx_types(tx, types, :coin_transfer)
  end

  defp tx_types(%Transaction{value: value}, types, :coin_transfer) do
    if Decimal.compare(value.value, 0) == :gt do
      [:coin_transfer | types]
    else
      types
    end
  end

  defp block_timestamp(%Transaction{block: %Block{} = block}), do: block.timestamp
  defp block_timestamp(%Block{} = block), do: block.timestamp
  defp block_timestamp(_), do: nil

  defp prepare_state_change(%StateChange{} = state_change) do
    coin_or_transfer =
      if state_change.coin_or_token_transfers == :coin,
        do: :coin,
        else: elem(List.first(state_change.coin_or_token_transfers), 1)

    type = if coin_or_transfer == :coin, do: "coin", else: "token"

    %{
      "address" =>
        Helper.address_with_info(nil, state_change.address, state_change.address && state_change.address.hash),
      "is_miner" => state_change.miner?,
      "type" => type,
      "token" => if(type == "token", do: TokenView.render("token.json", %{token: coin_or_transfer.token}))
    }
    |> append_balances(state_change.balance_before, state_change.balance_after)
    |> append_balance_change(state_change, coin_or_transfer)
  end

  defp append_balances(map, balance_before, balance_after) do
    balances =
      if TransactionStateView.not_negative?(balance_before) and TransactionStateView.not_negative?(balance_after) do
        %{
          "balance_before" => balance_before,
          "balance_after" => balance_after
        }
      else
        %{
          "balance_before" => nil,
          "balance_after" => nil
        }
      end

    Map.merge(map, balances)
  end

  defp append_balance_change(map, state_change, coin_or_transfer) do
    change =
      if is_list(state_change.coin_or_token_transfers) and coin_or_transfer.token.type != "ERC-20" do
        for {direction, token_transfer} <- state_change.coin_or_token_transfers do
          %{"total" => prepare_token_transfer_total(token_transfer), "direction" => direction}
        end
      else
        state_change.balance_diff
      end

    Map.merge(map, %{"change" => change})
  end
end
