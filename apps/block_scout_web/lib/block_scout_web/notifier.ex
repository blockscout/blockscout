defmodule BlockScoutWeb.Notifier do
  @moduledoc """
  Responds to events by sending appropriate channel updates to front-end.
  """

  alias Absinthe.Subscription
  alias BlockScoutWeb.{AddressContractVerificationView, Endpoint}
  alias Explorer.{Chain, Market, Repo}
  alias Explorer.Chain.{Address, InternalTransaction, TokenTransfer, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Supply.RSK
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Explorer.SmartContract.{Solidity.CodeCompiler, Solidity.CompilerVersion}
  alias Explorer.Staking.ContractState
  alias Phoenix.View

  def handle_event({:chain_event, :addresses, type, addresses}) when type in [:realtime, :on_demand] do
    Endpoint.broadcast("addresses:new_address", "count", %{count: Chain.address_estimated_count()})

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
        {:chain_event, :contract_verification_result, :on_demand, {address_hash, contract_verification_result, conn}}
      ) do
    contract_verification_result =
      case contract_verification_result do
        {:ok, _} = result ->
          result

        {:error, changeset} ->
          compiler_versions =
            case CompilerVersion.fetch_versions() do
              {:ok, compiler_versions} ->
                compiler_versions

              {:error, _} ->
                []
            end

          result =
            View.render_to_string(AddressContractVerificationView, "new.html",
              changeset: changeset,
              compiler_versions: compiler_versions,
              evm_versions: CodeCompiler.allowed_evm_versions(),
              address_hash: address_hash,
              conn: conn
            )

          {:error, result}
      end

    Endpoint.broadcast(
      "addresses:#{address_hash}",
      "verification_result",
      %{
        result: contract_verification_result
      }
    )
  end

  def handle_event({:chain_event, :block_rewards, :realtime, rewards}) do
    if Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:has_emission_funds] do
      broadcast_rewards(rewards)
    end
  end

  def handle_event({:chain_event, :blocks, :realtime, blocks}) do
    Enum.each(blocks, &broadcast_block/1)
  end

  def handle_event({:chain_event, :exchange_rate}) do
    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    market_history_data =
      case Market.fetch_recent_history() do
        [today | the_rest] -> [%{today | closing_price: exchange_rate.usd_value} | the_rest]
        data -> data
      end

    exchange_rate_with_available_supply =
      case Application.get_env(:explorer, :supply) do
        RSK ->
          %{exchange_rate | available_supply: nil, market_cap_usd: RSK.market_cap(exchange_rate)}

        _ ->
          exchange_rate
      end

    Endpoint.broadcast("exchange_rate:new_rate", "new_rate", %{
      exchange_rate: exchange_rate_with_available_supply,
      market_history_data: Enum.map(market_history_data, fn day -> Map.take(day, [:closing_price, :date]) end)
    })
  end

  def handle_event({:chain_event, :staking_update}) do
    Endpoint.broadcast("stakes:staking_update", "staking_update", %{
      block_number: BlockNumber.get_max(),
      epoch_number: ContractState.get(:epoch_number, 0),
      staking_allowed: ContractState.get(:staking_allowed, false),
      validator_set_apply_block: ContractState.get(:validator_set_apply_block, 0)
    })
  end

  def handle_event({:chain_event, :internal_transactions, :realtime, internal_transactions}) do
    internal_transactions
    |> Stream.map(
      &(InternalTransaction.where_nonpending_block()
        |> Repo.get_by(transaction_hash: &1.transaction_hash, index: &1.index)
        |> Repo.preload([:from_address, :to_address, transaction: :block]))
    )
    |> Enum.each(&broadcast_internal_transaction/1)
  end

  def handle_event({:chain_event, :token_transfers, :realtime, all_token_transfers}) do
    transfers_by_token = Enum.group_by(all_token_transfers, fn tt -> to_string(tt.token_contract_address_hash) end)

    for {token_contract_address_hash, token_transfers} <- transfers_by_token do
      Subscription.publish(
        Endpoint,
        token_transfers,
        token_transfers: token_contract_address_hash
      )

      token_transfers_full =
        token_transfers
        |> Stream.map(
          &(TokenTransfer
            |> Repo.get_by(
              transaction_hash: &1.transaction_hash,
              token_contract_address_hash: &1.token_contract_address_hash,
              log_index: &1.log_index
            )
            |> Repo.preload([:from_address, :to_address, :token, transaction: :block]))
        )

      token_transfers_full
      |> Enum.each(&broadcast_token_transfer/1)
    end
  end

  def handle_event({:chain_event, :transactions, :realtime, transactions}) do
    transactions
    |> Enum.map(& &1.hash)
    |> Chain.hashes_to_transactions(
      necessity_by_association: %{
        :block => :optional,
        [created_contract_address: :names] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional
      }
    )
    |> Enum.map(fn tx ->
      # Disable parsing of token transfers from websocket for transaction tab because we display token transfers at a separate tab
      Map.put(tx, :token_transfers, [])
    end)
    |> Enum.each(&broadcast_transaction/1)
  end

  def handle_event({:chain_event, :transaction_stats}) do
    today = Date.utc_today()

    [{:history_size, history_size}] =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.TransactionHistoryChartController, 30)

    x_days_back = Date.add(today, -1 * history_size)

    date_range = TransactionStats.by_date_range(x_days_back, today)
    stats = Enum.map(date_range, fn item -> Map.drop(item, [:__meta__]) end)

    Endpoint.broadcast("transactions:stats", "update", %{stats: stats})
  end

  def handle_event(_), do: nil

  @doc """
  Broadcast the percentage of blocks indexed so far.
  """
  def broadcast_blocks_indexed_ratio(ratio, finished?) do
    Endpoint.broadcast("blocks:indexing", "index_status", %{
      ratio: Decimal.to_string(ratio),
      finished: finished?
    })
  end

  defp broadcast_address_coin_balance(%{address_hash: address_hash, block_number: block_number}) do
    Endpoint.broadcast("addresses:#{address_hash}", "coin_balance", %{
      block_number: block_number
    })
  end

  defp broadcast_address_token_balance(%{address_hash: address_hash, block_number: block_number}) do
    Endpoint.broadcast("addresses:#{address_hash}", "token_balance", %{
      block_number: block_number
    })
  end

  defp broadcast_balance(%Address{hash: address_hash} = address) do
    Endpoint.broadcast(
      "addresses:#{address_hash}",
      "balance_update",
      %{
        address: address,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
      }
    )
  end

  defp broadcast_block(block) do
    preloaded_block = Repo.preload(block, [[miner: :names], :transactions, :rewards])
    average_block_time = AverageBlockTime.average_block_time()

    Endpoint.broadcast("blocks:new_block", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })

    Endpoint.broadcast("blocks:#{to_string(block.miner_hash)}", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })
  end

  defp broadcast_rewards(rewards) do
    preloaded_rewards = Repo.preload(rewards, [:address, :block])
    emission_reward = Enum.find(preloaded_rewards, fn reward -> reward.address_type == :emission_funds end)

    preloaded_rewards_except_emission =
      Enum.reject(preloaded_rewards, fn reward -> reward.address_type == :emission_funds end)

    Enum.each(preloaded_rewards_except_emission, fn reward ->
      Endpoint.broadcast("rewards:#{to_string(reward.address_hash)}", "new_reward", %{
        emission_funds: emission_reward,
        validator: reward
      })
    end)
  end

  defp broadcast_internal_transaction(internal_transaction) do
    Endpoint.broadcast("internal_transactions:new_internal_transaction", "new_internal_transaction", %{
      internal_transaction: internal_transaction
    })

    Endpoint.broadcast("addresses:#{internal_transaction.from_address_hash}", "internal_transaction", %{
      address: internal_transaction.from_address,
      internal_transaction: internal_transaction
    })

    if internal_transaction.to_address_hash != internal_transaction.from_address_hash do
      Endpoint.broadcast("addresses:#{internal_transaction.to_address_hash}", "internal_transaction", %{
        address: internal_transaction.to_address,
        internal_transaction: internal_transaction
      })
    end
  end

  defp broadcast_transaction(%Transaction{block_number: nil} = pending) do
    broadcast_transaction(pending, "transactions:new_pending_transaction", "pending_transaction")
  end

  defp broadcast_transaction(transaction) do
    broadcast_transaction(transaction, "transactions:new_transaction", "transaction")
  end

  defp broadcast_transaction(transaction, transaction_channel, event) do
    Endpoint.broadcast("transactions:#{transaction.hash}", "collated", %{})

    Endpoint.broadcast(transaction_channel, event, %{
      transaction: transaction
    })

    Endpoint.broadcast("addresses:#{transaction.from_address_hash}", event, %{
      address: transaction.from_address,
      transaction: transaction
    })

    if transaction.to_address_hash != transaction.from_address_hash do
      Endpoint.broadcast("addresses:#{transaction.to_address_hash}", event, %{
        address: transaction.to_address,
        transaction: transaction
      })
    end
  end

  defp broadcast_token_transfer(token_transfer) do
    broadcast_token_transfer(token_transfer, "token_transfers:new_token_transfer", "token_transfer")
  end

  defp broadcast_token_transfer(token_transfer, token_transfer_channel, event) do
    Endpoint.broadcast("token_transfers:#{token_transfer.transaction_hash}", event, %{})

    Endpoint.broadcast(token_transfer_channel, event, %{
      token_transfer: token_transfer
    })

    Endpoint.broadcast("addresses:#{token_transfer.from_address_hash}", event, %{
      address: token_transfer.from_address,
      token_transfer: token_transfer
    })

    Endpoint.broadcast("tokens:#{token_transfer.token_contract_address_hash}", event, %{
      address: token_transfer.token_contract_address_hash,
      token_transfer: token_transfer
    })

    if token_transfer.to_address_hash != token_transfer.from_address_hash do
      Endpoint.broadcast("addresses:#{token_transfer.to_address_hash}", event, %{
        address: token_transfer.to_address,
        token_transfer: token_transfer
      })
    end
  end
end
