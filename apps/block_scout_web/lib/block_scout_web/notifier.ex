defmodule BlockScoutWeb.Notifier do
  @moduledoc """
  Responds to events by sending appropriate channel updates to front-end.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  require Logger

  alias Absinthe.Subscription

  alias BlockScoutWeb.API.V2, as: API_V2

  alias BlockScoutWeb.API.V2.{
    AddressView,
    BlockView,
    PolygonZkevmView,
    SmartContractView,
    TransactionView
  }

  alias BlockScoutWeb.{
    AddressContractVerificationViaFlattenedCodeView,
    AddressContractVerificationViaJsonView,
    AddressContractVerificationViaMultiPartFilesView,
    AddressContractVerificationViaStandardJsonInputView,
    AddressContractVerificationVyperView,
    Endpoint
  }

  alias Explorer.{Chain, Market, Repo}

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    BlockNumberHelper,
    DenormalizationHelper,
    InternalTransaction,
    Token.Instance,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Cache.Counters.{AddressesCount, AverageBlockTime, Helper}
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.SmartContract.{CompilerVersion, Solidity.CodeCompiler}
  alias Phoenix.View
  alias Timex.Duration

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  @check_broadcast_sequence_period 500
  @api_true [api?: true]

  case @chain_type do
    :arbitrum ->
      @chain_type_specific_events ~w(new_arbitrum_batches new_messages_to_arbitrum_amount)a

    :optimism ->
      @chain_type_specific_events ~w(new_optimism_batches new_optimism_deposits)a

    _ ->
      nil
  end

  case @chain_type do
    :celo ->
      @chain_type_transaction_associations [
        :gas_token
      ]

    _ ->
      @chain_type_transaction_associations []
  end

  @transaction_associations [
                              from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()],
                              to_address: [
                                :scam_badge,
                                :names,
                                :smart_contract,
                                proxy_implementations_association()
                              ],
                              created_contract_address: [
                                :scam_badge,
                                :names,
                                :smart_contract,
                                proxy_implementations_association()
                              ]
                            ] ++
                              @chain_type_transaction_associations

  def handle_event({:chain_event, :addresses, type, addresses}) when type in [:realtime, :on_demand] do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:new_address", "count", %{count: AddressesCount.fetch()})
    Endpoint.broadcast("addresses:new_address", "count", %{count: AddressesCount.fetch()})

    addresses
    |> Stream.reject(fn %Address{fetched_coin_balance: fetched_coin_balance} -> is_nil(fetched_coin_balance) end)
    |> Enum.each(&broadcast_balance/1)
  end

  def handle_event({:chain_event, :address_coin_balances, type, address_coin_balances})
      when type in [:realtime, :on_demand] do
    Enum.each(address_coin_balances, &broadcast_address_coin_balance/1)
  end

  def handle_event({:chain_event, :address_token_balances, type, address_token_balances})
      when type in [:realtime, :on_demand] do
    Enum.each(address_token_balances, &broadcast_address_token_balance/1)
  end

  def handle_event(
        {:chain_event, :contract_verification_result, :on_demand, {address_hash, contract_verification_result}}
      ) do
    log_broadcast_verification_results_for_address(address_hash)
    v2_params = verification_result_params_v2(contract_verification_result)

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast(
      "addresses_old:#{address_hash}",
      "verification_result",
      %{
        result: contract_verification_result
      }
    )

    Endpoint.broadcast("addresses:#{address_hash}", "verification_result", v2_params)
  end

  def handle_event(
        {:chain_event, :contract_verification_result, :on_demand, {address_hash, contract_verification_result, conn}}
      ) do
    log_broadcast_verification_results_for_address(address_hash)
    %{view: view, compiler: compiler} = select_contract_type_and_form_view(conn.params)
    v2_params = verification_result_params_v2(contract_verification_result)

    contract_verification_result =
      case contract_verification_result do
        {:ok, _} = result ->
          result

        {:error, changeset} ->
          compiler_versions = fetch_compiler_version(compiler)

          result =
            view
            |> View.render_to_string("new.html",
              changeset: changeset,
              compiler_versions: compiler_versions,
              evm_versions: CodeCompiler.evm_versions(:solidity),
              address_hash: address_hash,
              conn: conn,
              retrying: true
            )

          {:error, result}
      end

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast(
      "addresses_old:#{address_hash}",
      "verification_result",
      %{
        result: contract_verification_result
      }
    )

    Endpoint.broadcast("addresses:#{address_hash}", "verification_result", v2_params)
  end

  def handle_event({:chain_event, :block_rewards, :realtime, rewards}) do
    if Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:has_emission_funds] do
      broadcast_rewards(rewards)
    end
  end

  def handle_event({:chain_event, :blocks, :realtime, blocks}) do
    last_broadcasted_block_number = Helper.fetch_from_ets_cache(:last_broadcasted_block, :number)

    blocks
    |> Enum.sort_by(& &1.number, :asc)
    |> Enum.each(fn block ->
      broadcast_latest_block?(block, last_broadcasted_block_number)
    end)
  end

  def handle_event({:chain_event, :zkevm_confirmed_batches, :realtime, batches}) do
    batches
    |> Enum.sort_by(& &1.number, :asc)
    |> Enum.each(fn confirmed_batch ->
      rendered_batch = PolygonZkevmView.render("zkevm_batch.json", %{batch: confirmed_batch, socket: nil})

      Endpoint.broadcast("zkevm_batches:new_zkevm_confirmed_batch", "new_zkevm_confirmed_batch", %{
        batch: rendered_batch
      })
    end)
  end

  def handle_event({:chain_event, :exchange_rate}) do
    exchange_rate = Market.get_coin_exchange_rate()

    market_history_data =
      Market.fetch_recent_history()
      |> case do
        [today | the_rest] -> [%{today | closing_price: exchange_rate.fiat_value} | the_rest]
        data -> data
      end
      |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)

    exchange_rate_with_available_supply =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          %{exchange_rate | available_supply: nil, market_cap: RSK.market_cap(exchange_rate)}

        _ ->
          Map.from_struct(exchange_rate)
      end

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("exchange_rate_old:new_rate", "new_rate", %{
      exchange_rate: exchange_rate_with_available_supply,
      market_history_data: market_history_data
    })

    Endpoint.broadcast("exchange_rate:new_rate", "new_rate", %{
      exchange_rate: exchange_rate_with_available_supply.fiat_value,
      available_supply: exchange_rate_with_available_supply.available_supply,
      chart_data: market_history_data
    })
  end

  def handle_event(
        {:chain_event, :internal_transactions, :on_demand,
         [%InternalTransaction{index: 0, transaction_hash: transaction_hash}]}
      ) do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("transactions_old:#{transaction_hash}", "raw_trace", %{raw_trace_origin: transaction_hash})

    internal_transactions = InternalTransaction.all_transaction_to_internal_transactions(transaction_hash)

    v2_params = %{
      raw_trace: TransactionView.render("raw_trace.json", %{internal_transactions: internal_transactions})
    }

    Endpoint.broadcast("transactions:#{transaction_hash}", "raw_trace", v2_params)
  end

  # internal transactions broadcast disabled on the indexer level, therefore it out of scope of the refactoring within https://github.com/blockscout/blockscout/pull/7474
  def handle_event({:chain_event, :internal_transactions, :realtime, internal_transactions}) do
    internal_transactions
    |> Stream.map(
      &(InternalTransaction.where_nonpending_block()
        |> Repo.get_by(transaction_hash: &1.transaction_hash, index: &1.index)
        |> Repo.preload([:from_address, :to_address, :block]))
    )
    |> Enum.each(&broadcast_internal_transaction/1)
  end

  def handle_event({:chain_event, :token_transfers, :realtime, all_token_transfers}) do
    all_token_transfers_full =
      all_token_transfers
      |> Repo.preload(
        DenormalizationHelper.extend_transaction_preload([
          :token,
          :transaction,
          from_address: [
            :scam_badge,
            :names,
            :smart_contract,
            proxy_implementations_association()
          ],
          to_address: [
            :scam_badge,
            :names,
            :smart_contract,
            proxy_implementations_association()
          ]
        ])
      )
      |> Instance.preload_nft(@api_true)

    transfers_by_token = Enum.group_by(all_token_transfers_full, fn tt -> to_string(tt.token_contract_address_hash) end)

    broadcast_token_transfers_websocket_v2(all_token_transfers_full, transfers_by_token)

    for {token_contract_address_hash, token_transfers} <- transfers_by_token do
      Subscription.publish(
        Endpoint,
        token_transfers,
        token_transfers: token_contract_address_hash
      )

      token_transfers
      |> Enum.each(&broadcast_token_transfer/1)
    end
  end

  def handle_event({:chain_event, :transactions, :realtime, transactions}) do
    base_preloads = [
      :block,
      created_contract_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()],
      from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()],
      to_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]
    ]

    preloads = if API_V2.enabled?(), do: [:token_transfers | base_preloads], else: base_preloads

    transactions
    |> Repo.preload(preloads)
    |> broadcast_transactions_websocket_v2()
    |> Enum.map(fn transaction ->
      # Disable parsing of token transfers from websocket for transaction tab because we display token transfers at a separate tab
      Map.put(transaction, :token_transfers, [])
    end)
    |> Enum.each(&broadcast_transaction/1)
  end

  def handle_event({:chain_event, :transaction_stats}) do
    today = Date.utc_today()

    [{:history_size, history_size}] =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.TransactionHistoryChartController, {:history_size, 30})

    x_days_back = Date.add(today, -1 * history_size)

    date_range = TransactionStats.by_date_range(x_days_back, today)
    stats = Enum.map(date_range, fn item -> Map.drop(item, [:__meta__]) end)

    Endpoint.broadcast("transactions_old:stats", "update", %{stats: stats})
  end

  def handle_event(
        {:chain_event, :token_total_supply, :on_demand,
         [%Explorer.Chain.Token{contract_address_hash: contract_address_hash, total_supply: total_supply} = token]}
      )
      when not is_nil(total_supply) do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("tokens_old:#{to_string(contract_address_hash)}", "token_total_supply", %{token: token})

    Endpoint.broadcast("tokens:#{to_string(contract_address_hash)}", "total_supply", %{
      total_supply: to_string(total_supply)
    })
  end

  def handle_event({:chain_event, :fetched_bytecode, :on_demand, [address_hash, fetched_bytecode]}) do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:#{to_string(address_hash)}", "fetched_bytecode", %{
      fetched_bytecode: fetched_bytecode
    })

    Endpoint.broadcast("addresses:#{to_string(address_hash)}", "fetched_bytecode", %{
      fetched_bytecode: fetched_bytecode
    })
  end

  def handle_event(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [token_contract_address_hash_string, token_id, fetched_token_instance_metadata]}
      ) do
    Endpoint.broadcast(
      "token_instances:#{token_contract_address_hash_string}",
      "fetched_token_instance_metadata",
      %{token_id: token_id, fetched_metadata: fetched_token_instance_metadata}
    )
  end

  def handle_event(
        {:chain_event, :not_fetched_token_instance_metadata, :on_demand,
         [token_contract_address_hash_string, token_id, reason]}
      ) do
    Endpoint.broadcast(
      "token_instances:#{token_contract_address_hash_string}",
      "not_fetched_token_instance_metadata",
      %{token_id: token_id, reason: reason}
    )
  end

  def handle_event({:chain_event, :changed_bytecode, :on_demand, [address_hash]}) do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:#{to_string(address_hash)}", "changed_bytecode", %{})
    Endpoint.broadcast("addresses:#{to_string(address_hash)}", "changed_bytecode", %{})
  end

  def handle_event({:chain_event, :smart_contract_was_verified = event, :on_demand, [address_hash]}) do
    broadcast_automatic_verification_events(event, address_hash)
  end

  def handle_event({:chain_event, :smart_contract_was_not_verified = event, :on_demand, [address_hash]}) do
    broadcast_automatic_verification_events(event, address_hash)
  end

  def handle_event({:chain_event, :eth_bytecode_db_lookup_started = event, :on_demand, [address_hash]}) do
    broadcast_automatic_verification_events(event, address_hash)
  end

  @current_token_balances_limit 50
  def handle_event({:chain_event, :address_current_token_balances, :on_demand, address_current_token_balances}) do
    address_current_token_balances.address_current_token_balances
    |> Enum.group_by(& &1.token_type)
    |> Enum.each(fn {token_type, balances} ->
      broadcast_token_balances(address_current_token_balances.address_hash, token_type, balances)
    end)
  end

  case @chain_type do
    :arbitrum ->
      def handle_event({:chain_event, topic, _, _} = event) when topic in @chain_type_specific_events,
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        do: BlockScoutWeb.Notifiers.Arbitrum.handle_event(event)

    :optimism ->
      def handle_event({:chain_event, topic, _, _} = event) when topic in @chain_type_specific_events,
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        do: BlockScoutWeb.Notifiers.Optimism.handle_event(event)

    _ ->
      nil
  end

  def handle_event(event) do
    Logger.warning("Unknown broadcasted event #{inspect(event)}.")
    nil
  end

  def fetch_compiler_version(compiler) do
    case CompilerVersion.fetch_versions(compiler) do
      {:ok, compiler_versions} ->
        compiler_versions

      {:error, _} ->
        []
    end
  end

  def select_contract_type_and_form_view(params) do
    verification_from_metadata_json? = check_verification_type(params, "json:metadata")

    verification_from_standard_json_input? = check_verification_type(params, "json:standard")

    verification_from_vyper? = check_verification_type(params, "vyper")

    verification_from_multi_part_files? = check_verification_type(params, "multi-part-files")

    compiler = if verification_from_vyper?, do: :vyper, else: :solc

    view =
      cond do
        verification_from_standard_json_input? -> AddressContractVerificationViaStandardJsonInputView
        verification_from_metadata_json? -> AddressContractVerificationViaJsonView
        verification_from_vyper? -> AddressContractVerificationVyperView
        verification_from_multi_part_files? -> AddressContractVerificationViaMultiPartFilesView
        true -> AddressContractVerificationViaFlattenedCodeView
      end

    %{view: view, compiler: compiler}
  end

  defp broadcast_token_balances(address_hash, token_type, balances) do
    sorted =
      Enum.sort_by(
        balances,
        fn ctb ->
          value =
            if ctb.token.decimals,
              do: Decimal.div(ctb.value, Decimal.new(Integer.pow(10, Decimal.to_integer(ctb.token.decimals)))),
              else: ctb.value

          {(ctb.token.fiat_value && Decimal.mult(value, ctb.token.fiat_value)) || Decimal.new(0), value}
        end,
        fn {fiat_value_1, value_1}, {fiat_value_2, value_2} ->
          case {Decimal.compare(fiat_value_1, fiat_value_2), Decimal.compare(value_1, value_2)} do
            {:gt, _} -> true
            {:eq, :gt} -> true
            {:eq, :eq} -> true
            _ -> false
          end
        end
      )

    event_postfix =
      token_type
      |> String.downcase()
      |> String.replace("-", "_")

    event = "updated_token_balances_" <> event_postfix

    Endpoint.broadcast("addresses:#{address_hash}", event, %{
      token_balances:
        AddressView.render("token_balances.json", %{
          token_balances: Enum.take(sorted, @current_token_balances_limit)
        }),
      overflow: Enum.count(sorted) > @current_token_balances_limit
    })
  end

  defp verification_result_params_v2({:ok, _contract}) do
    %{status: "success"}
  end

  defp verification_result_params_v2({:error, changeset}) do
    %{
      status: "error",
      errors: SmartContractView.render("changeset_errors.json", %{changeset: changeset})
    }
  end

  defp check_verification_type(params, type),
    do: Map.has_key?(params, "verification_type") && Map.get(params, "verification_type") == type

  @doc """
  Broadcast the percentage of blocks or pending block operations indexed so far.
  """
  @spec broadcast_indexed_ratio(String.t(), Decimal.t()) ::
          :ok | {:error, term()}
  def broadcast_indexed_ratio(msg, ratio) do
    Endpoint.broadcast(msg, "index_status", %{
      ratio: Decimal.to_string(ratio),
      finished: Chain.finished_indexing_from_ratio?(ratio)
    })
  end

  defp broadcast_latest_block?(block, last_broadcasted_block_number) do
    cond do
      last_broadcasted_block_number == 0 ||
        last_broadcasted_block_number == BlockNumberHelper.previous_block_number(block.number) ||
          last_broadcasted_block_number < block.number - 4 ->
        broadcast_block(block)
        :ets.insert(:last_broadcasted_block, {:number, block.number})

      last_broadcasted_block_number > BlockNumberHelper.previous_block_number(block.number) ->
        broadcast_block(block)

      true ->
        Task.start_link(fn ->
          schedule_broadcasting(block)
        end)
    end
  end

  defp schedule_broadcasting(block) do
    :timer.sleep(@check_broadcast_sequence_period)
    last_broadcasted_block_number = Helper.fetch_from_ets_cache(:last_broadcasted_block, :number)

    if last_broadcasted_block_number == BlockNumberHelper.previous_block_number(block.number) do
      broadcast_block(block)
      :ets.insert(:last_broadcasted_block, {:number, block.number})
    else
      schedule_broadcasting(block)
    end
  end

  defp broadcast_address_coin_balance(%{address_hash: address_hash, block_number: block_number}) do
    coin_balance = CoinBalance.get_coin_balance(address_hash, block_number)

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:#{address_hash}", "coin_balance", %{
      block_number: block_number,
      coin_balance: coin_balance
    })

    if coin_balance.value && coin_balance.delta do
      rendered_coin_balance = AddressView.render("coin_balance.json", %{coin_balance: coin_balance})

      Endpoint.broadcast("addresses:#{address_hash}", "coin_balance", %{
        coin_balance: rendered_coin_balance
      })

      Endpoint.broadcast("addresses:#{address_hash}", "current_coin_balance", %{
        coin_balance: coin_balance.value || %Wei{value: Decimal.new(0)},
        exchange_rate: Market.get_coin_exchange_rate().fiat_value,
        block_number: block_number
      })
    end
  end

  defp broadcast_address_token_balance(%{address_hash: address_hash, block_number: block_number}) do
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:#{address_hash}", "token_balance", %{
      block_number: block_number
    })

    Endpoint.broadcast("addresses:#{address_hash}", "token_balance", %{
      block_number: block_number
    })
  end

  defp broadcast_balance(%Address{hash: address_hash} = address) do
    exchange_rate = Market.get_coin_exchange_rate()

    v2_params = %{
      balance: address.fetched_coin_balance.value,
      block_number: address.fetched_coin_balance_block_number,
      exchange_rate: exchange_rate.fiat_value
    }

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast(
      "addresses_old:#{address_hash}",
      "balance_update",
      %{
        address: address,
        exchange_rate: exchange_rate
      }
    )

    Endpoint.broadcast("addresses:#{address_hash}", "balance", v2_params)
  end

  defp broadcast_block(block) do
    preloaded_block =
      Repo.preload(block, [
        [miner: [:names, :smart_contract, proxy_implementations_association()]],
        :transactions,
        :rewards
      ])

    average_block_time = AverageBlockTime.average_block_time()

    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("blocks_old:new_block", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })

    Endpoint.broadcast("blocks_old:#{to_string(block.miner_hash)}", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })

    block_params_v2 = %{
      average_block_time: to_string(Duration.to_milliseconds(average_block_time)),
      block:
        BlockView.render("block.json", %{
          block: preloaded_block,
          socket: nil
        })
    }

    Endpoint.broadcast("blocks:new_block", "new_block", block_params_v2)
    Endpoint.broadcast("blocks:#{to_string(block.miner_hash)}", "new_block", block_params_v2)
  end

  defp broadcast_rewards(rewards) do
    preloaded_rewards = Repo.preload(rewards, [:address, :block])
    emission_reward = Enum.find(preloaded_rewards, fn reward -> reward.address_type == :emission_funds end)

    preloaded_rewards_except_emission =
      Enum.reject(preloaded_rewards, fn reward -> reward.address_type == :emission_funds end)

    Enum.each(preloaded_rewards_except_emission, fn reward ->
      # TODO: delete duplicated event when old UI becomes deprecated
      Endpoint.broadcast("rewards_old:#{to_string(reward.address_hash)}", "new_reward", %{
        emission_funds: emission_reward,
        validator: reward
      })

      Endpoint.broadcast("rewards:#{to_string(reward.address_hash)}", "new_reward", %{reward: 1})
    end)
  end

  defp broadcast_internal_transaction(internal_transaction) do
    Endpoint.broadcast("addresses_old:#{internal_transaction.from_address_hash}", "internal_transaction", %{
      address: internal_transaction.from_address,
      internal_transaction: internal_transaction
    })

    if internal_transaction.to_address_hash != internal_transaction.from_address_hash do
      Endpoint.broadcast("addresses_old:#{internal_transaction.to_address_hash}", "internal_transaction", %{
        address: internal_transaction.to_address,
        internal_transaction: internal_transaction
      })
    end
  end

  defp broadcast_transactions_websocket_v2(transactions) do
    pending_transactions =
      Enum.filter(transactions, fn
        %Transaction{block_number: nil} -> true
        _ -> false
      end)

    validated_transactions =
      Enum.filter(transactions, fn
        %Transaction{block_number: nil} -> false
        _ -> true
      end)

    broadcast_transactions_websocket_v2_inner(
      pending_transactions,
      "transactions:new_pending_transaction",
      "pending_transaction"
    )

    broadcast_transactions_websocket_v2_inner(validated_transactions, "transactions:new_transaction", "transaction")

    transactions
  end

  defp broadcast_transactions_websocket_v2_inner(transactions, default_channel, event) do
    if not Enum.empty?(transactions) do
      Endpoint.broadcast(default_channel, event, %{
        String.to_existing_atom(event) => Enum.count(transactions)
      })
    end

    prepared_transactions =
      TransactionView.render("transactions.json", %{
        transactions: Repo.preload(transactions, @transaction_associations),
        conn: nil
      })

    transactions
    |> Enum.zip(prepared_transactions)
    |> group_by_address_hashes_and_broadcast(event, :transactions, & &1["hash"])
  end

  defp broadcast_transaction(%Transaction{block_number: nil} = pending) do
    broadcast_transaction(pending, "transactions_old:new_pending_transaction", "pending_transaction")
  end

  defp broadcast_transaction(transaction) do
    broadcast_transaction(transaction, "transactions_old:new_transaction", "transaction")
  end

  defp broadcast_transaction(transaction, transaction_channel, event) do
    Endpoint.broadcast("transactions_old:#{transaction.hash}", "collated", %{})

    Endpoint.broadcast(transaction_channel, event, %{
      transaction: transaction
    })

    Endpoint.broadcast("addresses_old:#{transaction.from_address_hash}", event, %{
      address: transaction.from_address,
      transaction: transaction
    })

    if transaction.to_address_hash != transaction.from_address_hash do
      Endpoint.broadcast("addresses_old:#{transaction.to_address_hash}", event, %{
        address: transaction.to_address,
        transaction: transaction
      })
    end
  end

  defp broadcast_token_transfers_websocket_v2(tokens_transfers, transfers_by_token) do
    for {token_contract_address_hash, token_transfers} <- transfers_by_token do
      Endpoint.broadcast("tokens:#{token_contract_address_hash}", "token_transfer", %{
        token_transfer: Enum.count(token_transfers)
      })
    end

    prepared_token_transfers =
      TransactionView.render("token_transfers.json", %{
        token_transfers: tokens_transfers,
        conn: nil
      })

    tokens_transfers
    |> Enum.zip(prepared_token_transfers)
    |> group_by_address_hashes_and_broadcast(
      "token_transfer",
      :token_transfers,
      &{&1["transaction_hash"], &1["block_hash"], &1["log_index"]}
    )
  end

  defp broadcast_token_transfer(token_transfer) do
    broadcast_token_transfer(token_transfer, "token_transfer")
  end

  defp broadcast_token_transfer(token_transfer, event) do
    Endpoint.broadcast("addresses_old:#{token_transfer.from_address_hash}", event, %{
      address: token_transfer.from_address,
      token_transfer: token_transfer
    })

    Endpoint.broadcast("tokens_old:#{token_transfer.token_contract_address_hash}", event, %{
      address: token_transfer.token_contract_address_hash,
      token_transfer: token_transfer
    })

    if token_transfer.to_address_hash != token_transfer.from_address_hash do
      Endpoint.broadcast("addresses_old:#{token_transfer.to_address_hash}", event, %{
        address: token_transfer.to_address,
        token_transfer: token_transfer
      })
    end
  end

  defp group_by_address_hashes_and_broadcast(elements, event, map_key, uniq_function) do
    grouped_by_from =
      elements
      |> Enum.group_by(fn {el, _} -> el.from_address_hash end, fn {_, prepared_el} -> prepared_el end)

    grouped_by_to =
      elements
      |> Enum.group_by(fn {el, _} -> el.to_address_hash end, fn {_, prepared_el} -> prepared_el end)

    grouped = Map.merge(grouped_by_to, grouped_by_from, fn _k, v1, v2 -> Enum.uniq_by(v1 ++ v2, uniq_function) end)

    for {address_hash, elements} <- grouped do
      Endpoint.broadcast("addresses:#{address_hash}", event, %{map_key => elements})
    end
  end

  defp log_broadcast_verification_results_for_address(address_hash) do
    Logger.info("Broadcast smart-contract #{address_hash} verification results")
  end

  defp log_broadcast_smart_contract_event(address_hash, event) do
    Logger.info("Broadcast smart-contract #{address_hash}: #{event}")
  end

  defp broadcast_automatic_verification_events(event, address_hash) do
    log_broadcast_smart_contract_event(address_hash, event)
    # TODO: delete duplicated event when old UI becomes deprecated
    Endpoint.broadcast("addresses_old:#{to_string(address_hash)}", to_string(event), %{})
    Endpoint.broadcast("addresses:#{to_string(address_hash)}", to_string(event), %{})
  end
end
