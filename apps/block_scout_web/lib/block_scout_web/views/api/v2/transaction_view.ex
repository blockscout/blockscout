defmodule BlockScoutWeb.API.V2.TransactionView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.API.V2.{ApiView, Helper, InternalTransactionView, TokenTransferView, TokenView}

  alias BlockScoutWeb.Models.GetTransactionTags
  alias BlockScoutWeb.{TransactionStateView, TransactionView}
  alias Ecto.Association.NotLoaded
  alias Explorer.{Chain, Market}

  alias Explorer.Chain.{
    Address,
    Block,
    DecodingHelper,
    Log,
    SignedAuthorization,
    SmartContract,
    Token,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation, as: ProxyImplementation
  alias Explorer.Chain.Transaction.StateChange
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
    block_height = Chain.block_height(@api_true)
    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    %{
      "items" =>
        transactions
        |> with_chain_type_transformations()
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {transaction, decoded_input} ->
          prepare_transaction(transaction, conn, false, block_height, watchlist_names, decoded_input)
        end),
      "next_page_params" => next_page_params
    }
  end

  def render("transactions_watchlist.json", %{
        transactions: transactions,
        conn: conn,
        watchlist_names: watchlist_names
      }) do
    block_height = Chain.block_height(@api_true)
    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    transactions
    |> with_chain_type_transformations()
    |> Enum.zip(decoded_transactions)
    |> Enum.map(fn {transaction, decoded_input} ->
      prepare_transaction(transaction, conn, false, block_height, watchlist_names, decoded_input)
    end)
  end

  def render("transactions.json", %{transactions: transactions, next_page_params: next_page_params, conn: conn}) do
    block_height = Chain.block_height(@api_true)
    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    %{
      "items" =>
        transactions
        |> with_chain_type_transformations()
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {transaction, decoded_input} ->
          prepare_transaction(transaction, conn, false, block_height, decoded_input)
        end),
      "next_page_params" => next_page_params
    }
  end

  def render("transactions.json", %{transactions: transactions, items: true, conn: conn}) do
    %{
      "items" => render("transactions.json", %{transactions: transactions, conn: conn})
    }
  end

  def render("transactions.json", %{transactions: transactions, conn: conn}) do
    block_height = Chain.block_height(@api_true)
    decoded_transactions = Transaction.decode_transactions(transactions, true, @api_true)

    transactions
    |> with_chain_type_transformations()
    |> Enum.zip(decoded_transactions)
    |> Enum.map(fn {transaction, decoded_input} ->
      prepare_transaction(transaction, conn, false, block_height, decoded_input)
    end)
  end

  def render("transaction.json", %{transaction: transaction, conn: conn}) do
    block_height = Chain.block_height(@api_true)
    [decoded_input] = Transaction.decode_transactions([transaction], false, @api_true)

    transaction
    |> with_chain_type_transformations()
    |> prepare_transaction(conn, true, block_height, decoded_input)
  end

  def render("raw_trace.json", %{raw_traces: raw_traces}) do
    raw_traces
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
    decoded_transactions =
      Transaction.decode_transactions(Enum.map(token_transfers, fn tt -> tt.transaction end), true, @api_true)

    %{
      "items" =>
        token_transfers
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {tt, decoded_input} -> TokenTransferView.prepare_token_transfer(tt, conn, decoded_input) end),
      "next_page_params" => next_page_params
    }
  end

  def render("token_transfers.json", %{token_transfers: token_transfers, conn: conn}) do
    decoded_transactions =
      Transaction.decode_transactions(Enum.map(token_transfers, fn tt -> tt.transaction end), true, @api_true)

    token_transfers
    |> Enum.zip(decoded_transactions)
    |> Enum.map(fn {tt, decoded_input} -> TokenTransferView.prepare_token_transfer(tt, conn, decoded_input) end)
  end

  def render("token_transfer.json", %{token_transfer: token_transfer, conn: conn}) do
    [decoded_transaction] = Transaction.decode_transactions([token_transfer.transaction], true, @api_true)
    TokenTransferView.prepare_token_transfer(token_transfer, conn, decoded_transaction)
  end

  def render("transaction_actions.json", %{actions: actions}) do
    Enum.map(actions, &prepare_transaction_action(&1))
  end

  def render("internal_transactions.json", %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params,
        block: block
      }) do
    %{
      "items" => Enum.map(internal_transactions, &InternalTransactionView.prepare_internal_transaction(&1, block)),
      "next_page_params" => next_page_params
    }
  end

  def render("internal_transactions.json", %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(internal_transactions, &InternalTransactionView.prepare_internal_transaction(&1)),
      "next_page_params" => next_page_params
    }
  end

  def render("logs.json", %{logs: logs, next_page_params: next_page_params, transaction_hash: transaction_hash}) do
    decoded_logs = decode_logs(logs, false)

    %{
      "items" =>
        logs
        |> Enum.zip(decoded_logs)
        |> Enum.map(fn {log, decoded_log} -> prepare_log(log, transaction_hash, decoded_log) end),
      "next_page_params" => next_page_params
    }
  end

  def render("logs.json", %{logs: logs, next_page_params: next_page_params}) do
    decoded_logs = decode_logs(logs, false)

    %{
      "items" =>
        logs
        |> Enum.zip(decoded_logs)
        |> Enum.map(fn {log, decoded_log} -> prepare_log(log, log.transaction, decoded_log) end),
      "next_page_params" => next_page_params
    }
  end

  def render("state_changes.json", %{state_changes: state_changes, next_page_params: next_page_params}) do
    %{
      "items" => Enum.map(state_changes, &prepare_state_change(&1)),
      "next_page_params" => next_page_params
    }
  end

  def render("stats.json", %{
        transactions_count_24h: transactions_count,
        pending_transactions_count: pending_transactions_count,
        transaction_fees_sum_24h: transaction_fees_sum,
        transaction_fees_avg_24h: transaction_fees_avg
      }) do
    %{
      "transactions_count_24h" => transactions_count,
      "pending_transactions_count" => pending_transactions_count,
      "transaction_fees_sum_24h" => transaction_fees_sum,
      "transaction_fees_avg_24h" => transaction_fees_avg
    }
  end

  def render("authorization_list.json", %{signed_authorizations: signed_authorizations}) do
    signed_authorizations
    |> Enum.sort_by(& &1.index, :asc)
    |> Enum.map(&prepare_signed_authorization/1)
  end

  @doc """
  Returns the ABI of a smart contract or an empty list if the smart contract is nil
  """
  @spec try_to_get_abi(SmartContract.t() | nil) :: [map()]
  def try_to_get_abi(smart_contract) do
    (smart_contract && smart_contract.abi) || []
  end

  @doc """
  Returns the ABI of a proxy implementations or an empty list if the proxy implementations is nil
  """
  @spec extract_implementations_abi(ProxyImplementation.t() | nil) :: [map()]
  def extract_implementations_abi(nil) do
    []
  end

  def extract_implementations_abi(proxy_implementations) do
    proxy_implementations.smart_contracts
    |> Enum.flat_map(fn smart_contract ->
      try_to_get_abi(smart_contract)
    end)
  end

  @doc """
    Decodes list of logs
  """
  @spec decode_logs([Log.t()], boolean()) :: [tuple() | nil]
  def decode_logs(logs, skip_sig_provider?) do
    full_abi_per_address_hash =
      Enum.reduce(logs, %{}, fn log, acc ->
        full_abi =
          (extract_implementations_abi(log.address.proxy_implementations) ++
             try_to_get_abi(log.address.smart_contract))
          |> Enum.uniq()

        Map.put(acc, log.address_hash, full_abi)
      end)

    {all_logs, _} =
      Enum.reduce(logs, {[], %{}}, fn log, {results, events_acc} ->
        {result, events_acc} =
          Log.decode(
            log,
            %Transaction{hash: log.transaction_hash},
            @api_true,
            skip_sig_provider?,
            true,
            full_abi_per_address_hash[log.address_hash],
            events_acc
          )

        {[result | results], events_acc}
      end)

    all_logs_with_index =
      all_logs
      |> Enum.reverse()
      |> Enum.with_index(fn element, index -> {index, element} end)

    %{
      :already_decoded_or_ignored_logs => already_decoded_or_ignored_logs,
      :input_for_sig_provider_batched_request => input_for_sig_provider_batched_request
    } =
      all_logs_with_index
      |> Enum.reduce(
        %{
          :already_decoded_or_ignored_logs => [],
          :input_for_sig_provider_batched_request => []
        },
        fn {index, result}, acc ->
          case result do
            {:error, :try_with_sig_provider, {log, _transaction_hash}} when is_nil(log.first_topic) ->
              Map.put(acc, :already_decoded_or_ignored_logs, [
                {index, {:error, :could_not_decode}} | acc.already_decoded_or_ignored_logs
              ])

            {:error, :try_with_sig_provider, {log, transaction_hash}} ->
              Map.put(acc, :input_for_sig_provider_batched_request, [
                {index,
                 %{
                   :log => log,
                   :transaction_hash => transaction_hash
                 }}
                | acc.input_for_sig_provider_batched_request
              ])

            _ ->
              Map.put(acc, :already_decoded_or_ignored_logs, [{index, result} | acc.already_decoded_or_ignored_logs])
          end
        end
      )

    decoded_with_sig_provider_logs =
      Log.decode_events_batch_via_sig_provider(input_for_sig_provider_batched_request, skip_sig_provider?)

    full_logs = already_decoded_or_ignored_logs ++ decoded_with_sig_provider_logs

    full_logs
    |> Enum.sort_by(fn {index, _log} -> index end, :asc)
    |> Enum.map(fn {_index, log} ->
      format_decoded_log_input(log)
    end)
  end

  def prepare_transaction_action(action) do
    %{
      "protocol" => action.protocol,
      "type" => action.type,
      "data" => action.data
    }
  end

  def prepare_log(log, transaction_or_hash, decoded_log, tags_for_address_needed? \\ false) do
    decoded = process_decoded_log(decoded_log)

    %{
      "transaction_hash" => get_transaction_hash(transaction_or_hash),
      "address" => Helper.address_with_info(nil, log.address, log.address_hash, tags_for_address_needed?),
      "topics" => [
        log.first_topic,
        log.second_topic,
        log.third_topic,
        log.fourth_topic
      ],
      "data" => log.data,
      "index" => log.index,
      "decoded" => decoded,
      "smart_contract" => smart_contract_info(transaction_or_hash),
      "block_number" => log.block_number,
      "block_hash" => log.block_hash
    }
  end

  @doc """
    Extracts the necessary fields from the signed authorization for the API response.

    ## Parameters
    - `signed_authorization`: A `SignedAuthorization.t()` struct containing the signed authorization data.

    ## Returns
    - A map with the necessary fields for the API response.
  """
  @spec prepare_signed_authorization(SignedAuthorization.t()) :: map()
  def prepare_signed_authorization(signed_authorization) do
    %{
      "address_hash" => Address.checksum(signed_authorization.address),
      # todo: It should be removed in favour `address_hash` property with the next release after 8.0.0
      "address" => Address.checksum(signed_authorization.address),
      "chain_id" => signed_authorization.chain_id,
      "nonce" => signed_authorization.nonce,
      "r" => signed_authorization.r,
      "s" => signed_authorization.s,
      "v" => signed_authorization.v,
      "authority" => Address.checksum(signed_authorization.authority),
      "status" => signed_authorization.status
    }
  end

  defp get_transaction_hash(%Transaction{} = transaction), do: to_string(transaction.hash)
  defp get_transaction_hash(hash), do: to_string(hash)

  defp smart_contract_info(%Transaction{} = transaction),
    do: Helper.address_with_info(nil, transaction.to_address, transaction.to_address_hash, false)

  defp smart_contract_info(_), do: nil

  defp process_decoded_log(decoded_log) do
    case decoded_log do
      {:ok, method_id, text, mapping} ->
        render(__MODULE__, "decoded_log_input.json", method_id: method_id, text: text, mapping: mapping)

      _ ->
        nil
    end
  end

  defp prepare_transaction(transaction, conn, single_transaction?, block_height, watchlist_names \\ nil, decoded_input)

  defp prepare_transaction(
         {%Reward{} = emission_reward, %Reward{} = validator_reward},
         conn,
         single_transaction?,
         _block_height,
         _watchlist_names,
         _decoded_input
       ) do
    %{
      "emission_reward" => emission_reward.reward,
      "block_hash" => validator_reward.block_hash,
      "from" =>
        Helper.address_with_info(
          single_transaction? && conn,
          emission_reward.address,
          emission_reward.address_hash,
          single_transaction?
        ),
      "to" =>
        Helper.address_with_info(
          single_transaction? && conn,
          validator_reward.address,
          validator_reward.address_hash,
          single_transaction?
        ),
      "types" => [:reward]
    }
  end

  defp prepare_transaction(
         %Transaction{} = transaction,
         conn,
         single_transaction?,
         block_height,
         watchlist_names,
         decoded_input
       ) do
    base_fee_per_gas = transaction.block && transaction.block.base_fee_per_gas
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas
    max_fee_per_gas = transaction.max_fee_per_gas

    priority_fee_per_gas = Transaction.priority_fee_per_gas(max_priority_fee_per_gas, base_fee_per_gas, max_fee_per_gas)

    burnt_fees = burnt_fees(transaction, max_fee_per_gas, base_fee_per_gas)

    status = transaction |> Chain.transaction_to_status() |> format_status()

    revert_reason = revert_reason(status, transaction, single_transaction?)

    decoded_input_data = decoded_input(decoded_input)

    result = %{
      "hash" => transaction.hash,
      "result" => status,
      "status" => transaction.status,
      "block_number" => transaction.block_number,
      "timestamp" => block_timestamp(transaction),
      "from" =>
        Helper.address_with_info(
          single_transaction? && conn,
          transaction.from_address,
          transaction.from_address_hash,
          single_transaction?,
          watchlist_names
        ),
      "to" =>
        Helper.address_with_info(
          single_transaction? && conn,
          transaction.to_address,
          transaction.to_address_hash,
          single_transaction?,
          watchlist_names
        ),
      "created_contract" =>
        Helper.address_with_info(
          single_transaction? && conn,
          transaction.created_contract_address,
          transaction.created_contract_address_hash,
          single_transaction?,
          watchlist_names
        ),
      "confirmations" => transaction.block |> Chain.confirmations(block_height: block_height) |> format_confirmations(),
      "confirmation_duration" => processing_time_duration(transaction),
      "value" => transaction.value,
      "fee" => transaction |> Transaction.fee(:wei) |> format_fee(),
      "gas_price" => transaction.gas_price || Transaction.effective_gas_price(transaction),
      "type" => transaction.type,
      "gas_used" => transaction.gas_used,
      "gas_limit" => transaction.gas,
      "max_fee_per_gas" => transaction.max_fee_per_gas,
      "max_priority_fee_per_gas" => transaction.max_priority_fee_per_gas,
      "base_fee_per_gas" => base_fee_per_gas,
      "priority_fee" => priority_fee_per_gas && Wei.mult(priority_fee_per_gas, transaction.gas_used),
      "transaction_burnt_fee" => burnt_fees,
      "nonce" => transaction.nonce,
      "position" => transaction.index,
      "revert_reason" => revert_reason,
      "raw_input" => transaction.input,
      "decoded_input" => decoded_input_data,
      "token_transfers" => token_transfers(transaction.token_transfers, conn, single_transaction?),
      "token_transfers_overflow" => token_transfers_overflow(transaction.token_transfers, single_transaction?),
      "actions" => transaction_actions(transaction.transaction_actions),
      "exchange_rate" => Market.get_coin_exchange_rate().fiat_value,
      "historic_exchange_rate" =>
        Market.get_coin_exchange_rate_at_date(block_timestamp(transaction), @api_true).fiat_value,
      "method" => Transaction.method_name(transaction, decoded_input),
      "transaction_types" => transaction_types(transaction),
      "transaction_tag" =>
        GetTransactionTags.get_transaction_tags(transaction.hash, current_user(single_transaction? && conn)),
      "has_error_in_internal_transactions" => transaction.has_error_in_internal_transactions,
      "authorization_list" => authorization_list(transaction.signed_authorizations)
    }

    result
    |> with_chain_type_fields(transaction, single_transaction?, conn, watchlist_names)
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

  def transaction_actions(%NotLoaded{}), do: []

  @doc """
    Renders transaction actions
  """
  def transaction_actions(actions) do
    render("transaction_actions.json", %{actions: actions})
  end

  @doc """
    Renders the authorization list for a transaction.

    ## Parameters
    - `signed_authorizations`: A list of `SignedAuthorization.t()` structs.

    ## Returns
    - A list of maps with the necessary fields for the API response.
  """
  @spec authorization_list(nil | NotLoaded.t() | [SignedAuthorization.t()]) :: [map()]
  def authorization_list(nil), do: []
  def authorization_list(%NotLoaded{}), do: []

  def authorization_list(signed_authorizations) do
    render("authorization_list.json", %{signed_authorizations: signed_authorizations})
  end

  defp burnt_fees(transaction, max_fee_per_gas, base_fee_per_gas) do
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

  defp revert_reason(status, transaction, single_transaction?) do
    reverted? = is_binary(status) && status |> String.downcase() |> String.contains?("reverted")

    cond do
      reverted? && single_transaction? ->
        prepare_revert_reason_for_single_transaction(transaction)

      reverted? && !single_transaction? ->
        %Transaction{revert_reason: revert_reason} = transaction
        render(__MODULE__, "revert_reason.json", raw: revert_reason)

      true ->
        nil
    end
  rescue
    _ ->
      nil
  end

  defp prepare_revert_reason_for_single_transaction(transaction) do
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

  @doc """
    Prepares decoded transaction info
  """
  @spec decoded_input(any()) :: map() | nil
  def decoded_input(decoded_input) do
    case decoded_input do
      {:ok, method_id, text, mapping} ->
        render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: false)

      _ ->
        nil
    end
  end

  def prepare_method_mapping(mapping) do
    Enum.map(mapping, fn {name, type, value} ->
      %{"name" => name, "type" => type, "value" => DecodingHelper.value_json(type, value)}
    end)
  end

  def prepare_log_mapping(mapping) do
    Enum.map(mapping, fn {name, type, indexed?, value} ->
      %{"name" => name, "type" => type, "indexed" => indexed?, "value" => DecodingHelper.value_json(type, value)}
    end)
  end

  defp format_status({:error, reason}), do: reason
  defp format_status(status), do: status

  defp format_decoded_log_input({:error, :could_not_decode}), do: nil
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

  @doc """
    Returns array of token types for transaction.
  """
  @spec transaction_types(
          Explorer.Chain.Transaction.t(),
          [transaction_type],
          transaction_type
        ) :: [transaction_type]
        when transaction_type:
               :coin_transfer
               | :contract_call
               | :contract_creation
               | :rootstock_bridge
               | :rootstock_remasc
               | :token_creation
               | :token_transfer
               | :blob_transaction
               | :set_code_transaction
  def transaction_types(transaction, types \\ [], stage \\ :set_code_transaction)

  def transaction_types(%Transaction{type: type} = transaction, types, :set_code_transaction) do
    # EIP-7702 set code transaction type
    types =
      if type == 4 do
        [:set_code_transaction | types]
      else
        types
      end

    transaction_types(transaction, types, :blob_transaction)
  end

  def transaction_types(%Transaction{type: type} = transaction, types, :blob_transaction) do
    # EIP-2718 blob transaction type
    types =
      if type == 3 do
        [:blob_transaction | types]
      else
        types
      end

    transaction_types(transaction, types, :token_transfer)
  end

  def transaction_types(%Transaction{token_transfers: token_transfers} = transaction, types, :token_transfer) do
    types =
      if (!is_nil(token_transfers) && token_transfers != [] && !match?(%NotLoaded{}, token_transfers)) ||
           transaction.has_token_transfers do
        [:token_transfer | types]
      else
        types
      end

    transaction_types(transaction, types, :token_creation)
  end

  def transaction_types(
        %Transaction{created_contract_address: created_contract_address} = transaction,
        types,
        :token_creation
      ) do
    types =
      if match?(%Address{}, created_contract_address) && match?(%Token{}, created_contract_address.token) do
        [:token_creation | types]
      else
        types
      end

    transaction_types(transaction, types, :contract_creation)
  end

  def transaction_types(
        %Transaction{to_address_hash: to_address_hash} = transaction,
        types,
        :contract_creation
      ) do
    types =
      if is_nil(to_address_hash) do
        [:contract_creation | types]
      else
        types
      end

    transaction_types(transaction, types, :contract_call)
  end

  def transaction_types(%Transaction{to_address: to_address} = transaction, types, :contract_call) do
    types =
      if Address.smart_contract?(to_address) do
        [:contract_call | types]
      else
        types
      end

    transaction_types(transaction, types, :coin_transfer)
  end

  def transaction_types(%Transaction{value: value} = transaction, types, :coin_transfer) do
    types =
      if Decimal.compare(value.value, 0) == :gt do
        [:coin_transfer | types]
      else
        types
      end

    transaction_types(transaction, types, :rootstock_remasc)
  end

  def transaction_types(transaction, types, :rootstock_remasc) do
    types =
      if Transaction.rootstock_remasc_transaction?(transaction) do
        [:rootstock_remasc | types]
      else
        types
      end

    transaction_types(transaction, types, :rootstock_bridge)
  end

  def transaction_types(transaction, types, :rootstock_bridge) do
    if Transaction.rootstock_bridge_transaction?(transaction) do
      [:rootstock_bridge | types]
    else
      types
    end
  end

  @doc """
  Returns block's timestamp from Block/Transaction
  """
  @spec block_timestamp(any()) :: :utc_datetime_usec | nil
  def block_timestamp(%Transaction{block_timestamp: block_ts}) when not is_nil(block_ts), do: block_ts
  def block_timestamp(%Transaction{block: %Block{} = block}), do: block.timestamp
  def block_timestamp(%Block{} = block), do: block.timestamp
  def block_timestamp(_), do: nil

  defp prepare_state_change(%StateChange{} = state_change) do
    coin_or_transfer =
      if state_change.coin_or_token_transfers == :coin,
        do: :coin,
        else: elem(List.first(state_change.coin_or_token_transfers), 1)

    type = if coin_or_transfer == :coin, do: "coin", else: "token"

    %{
      "address" =>
        Helper.address_with_info(nil, state_change.address, state_change.address && state_change.address.hash, false),
      "is_miner" => state_change.miner?,
      "type" => type,
      "token" => if(type == "token", do: TokenView.render("token.json", %{token: coin_or_transfer.token})),
      "token_id" => state_change.token_id
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
      if is_list(state_change.coin_or_token_transfers) and coin_or_transfer.token.type == "ERC-721" do
        for {direction, token_transfer} <- state_change.coin_or_token_transfers do
          %{"total" => TokenTransferView.prepare_token_transfer_total(token_transfer), "direction" => direction}
        end
      else
        state_change.balance_diff
      end

    Map.merge(map, %{"change" => change})
  end

  defp with_chain_type_transformations(transactions) do
    chain_type = Application.get_env(:explorer, :chain_type)
    do_with_chain_type_transformations(chain_type, transactions)
  end

  defp do_with_chain_type_transformations(:stability, transactions) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.StabilityView.transform_transactions(transactions)
  end

  defp do_with_chain_type_transformations(_chain_type, transactions) do
    transactions
  end

  defp with_chain_type_fields(result, transaction, single_transaction?, conn, watchlist_names) do
    chain_type = Application.get_env(:explorer, :chain_type)
    do_with_chain_type_fields(chain_type, result, transaction, single_transaction?, conn, watchlist_names)
  end

  defp do_with_chain_type_fields(
         :polygon_edge,
         result,
         transaction,
         true = _single_transaction?,
         conn,
         _watchlist_names
       ) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.PolygonEdgeView.extend_transaction_json_response(result, transaction.hash, conn)
  end

  defp do_with_chain_type_fields(
         :polygon_zkevm,
         result,
         transaction,
         true = _single_transaction?,
         _conn,
         _watchlist_names
       ) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.PolygonZkevmView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:zksync, result, transaction, true = _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.ZkSyncView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:arbitrum, result, transaction, true = _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.ArbitrumView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:optimism, result, transaction, true = _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.OptimismView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:scroll, result, transaction, true = _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.ScrollView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:suave, result, transaction, true = single_transaction?, conn, watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.SuaveView.extend_transaction_json_response(
      transaction,
      result,
      single_transaction?,
      conn,
      watchlist_names
    )
  end

  defp do_with_chain_type_fields(:stability, result, transaction, _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.StabilityView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:ethereum, result, transaction, _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.EthereumView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:celo, result, transaction, _single_transaction?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.CeloView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(:zilliqa, result, transaction, _single_tx?, _conn, _watchlist_names) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    BlockScoutWeb.API.V2.ZilliqaView.extend_transaction_json_response(result, transaction)
  end

  defp do_with_chain_type_fields(_chain_type, result, _transaction, _single_transaction?, _conn, _watchlist_names) do
    result
  end
end
