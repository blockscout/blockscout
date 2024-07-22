defmodule BlockScoutWeb.Models.TransactionStateHelper do
  @moduledoc """
    Transaction state changes related functions
  """

  import BlockScoutWeb.Chain, only: [default_paging_options: 0]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Chain.Transaction.StateChange
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{BlockNumberHelper, Transaction, Wei}
  alias Explorer.Chain.Cache.StateChanges
  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand
  alias Indexer.Fetcher.OnDemand.TokenBalance, as: TokenBalanceOnDemand

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  @doc """
  This function takes transaction, fetches all the transactions before this one from the same block
  together with internal transactions and token transfers and calculates native coin and token
  balances before and after this transaction.
  """
  @spec state_changes(Transaction.t(), [Chain.paging_options() | Chain.api?()]) :: [StateChange.t()]
  def state_changes(transaction, options \\ [])

  def state_changes(%Transaction{} = transaction, options) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())
    {offset} = paging_options.key || {0}

    offset
    |> Kernel.==(0)
    |> if do
      get_and_cache_state_changes(transaction, options)
    else
      case StateChanges.get(transaction.hash) do
        %StateChanges{state_changes: state_changes} -> state_changes
        _ -> get_and_cache_state_changes(transaction, options)
      end
    end
    |> Enum.drop(offset)
  end

  def state_changes(_transaction, _options), do: []

  defp get_and_cache_state_changes(transaction, options) do
    state_changes = do_state_changes(transaction, options)

    StateChanges.update(%StateChanges{
      transaction_hash: transaction.hash,
      state_changes: state_changes
    })

    state_changes
  end

  defp do_state_changes(%Transaction{} = transaction, options) do
    block_txs =
      transaction.block_hash
      |> Chain.block_to_transactions(
        paging_options: %PagingOptions{key: nil, page_size: nil},
        api?: Keyword.get(options, :api?, false)
      )
      |> Enum.filter(&(&1.index <= transaction.index))
      |> Repo.preload([:token_transfers, :internal_transactions])

    transaction =
      block_txs
      |> Enum.find(&(&1.hash == transaction.hash))
      |> Repo.preload(
        token_transfers: [
          from_address: [:names, :smart_contract, :proxy_implementations],
          to_address: [:names, :smart_contract, :proxy_implementations]
        ],
        internal_transactions: [
          from_address: [:names, :smart_contract, :proxy_implementations],
          to_address: [:names, :smart_contract, :proxy_implementations]
        ],
        block: [miner: [:names, :smart_contract, :proxy_implementations]],
        from_address: [:names, :smart_contract, :proxy_implementations],
        to_address: [:names, :smart_contract, :proxy_implementations]
      )

    previous_block_number = BlockNumberHelper.previous_block_number(transaction.block_number)

    coin_balances_before_block = transaction_to_coin_balances(transaction, previous_block_number, options)

    coin_balances_before_tx = StateChange.coin_balances_before(transaction, block_txs, coin_balances_before_block)

    native_coin_entries = StateChange.native_coin_entries(transaction, coin_balances_before_tx)

    token_balances_before =
      transaction.token_transfers
      |> Enum.reduce(%{}, &token_transfers_to_balances_reducer(&1, &2, previous_block_number, options))
      |> StateChange.token_balances_before(transaction, block_txs)

    tokens_entries = StateChange.token_entries(transaction.token_transfers, token_balances_before)

    native_coin_entries ++ tokens_entries
  end

  defp transaction_to_coin_balances(transaction, previous_block_number, options) do
    Enum.reduce(
      transaction.internal_transactions,
      %{
        transaction.from_address_hash =>
          {transaction.from_address, coin_balance(transaction.from_address_hash, previous_block_number, options)},
        transaction.to_address_hash =>
          {transaction.to_address, coin_balance(transaction.to_address_hash, previous_block_number, options)},
        transaction.block.miner_hash =>
          {transaction.block.miner, coin_balance(transaction.block.miner_hash, previous_block_number, options)}
      },
      &internal_transaction_to_coin_balances(&1, previous_block_number, options, &2)
    )
  end

  defp internal_transaction_to_coin_balances(internal_transaction, previous_block_number, options, acc) do
    if internal_transaction.value |> Wei.to(:wei) |> Decimal.positive?() do
      acc
      |> Map.put_new_lazy(internal_transaction.from_address_hash, fn ->
        {internal_transaction.from_address,
         coin_balance(internal_transaction.from_address_hash, previous_block_number, options)}
      end)
      |> Map.put_new_lazy(internal_transaction.to_address_hash, fn ->
        {internal_transaction.to_address,
         coin_balance(internal_transaction.to_address_hash, previous_block_number, options)}
      end)
    else
      acc
    end
  end

  defp coin_balance(address_hash, _block_number, _options) when is_nil(address_hash) do
    %Wei{value: Decimal.new(0)}
  end

  defp coin_balance(address_hash, block_number, options) do
    case Chain.get_coin_balance(address_hash, block_number, options) do
      %{value: val} when not is_nil(val) ->
        val

      _ ->
        CoinBalanceOnDemand.trigger_historic_fetch(address_hash, block_number)
        %Wei{value: Decimal.new(0)}
    end
  end

  defp token_balances(address_hash, token_transfer, block_number, options) do
    token = token_transfer.token

    token_ids =
      if token.type == "ERC-1155" do
        token_transfer.token_ids
      else
        [nil]
      end

    Enum.into(token_ids, %{transfers: []}, &{&1, token_balance(address_hash, block_number, token, &1, options)})
  end

  defp token_balance(@burn_address_hash, _block_number, _token, _token_id, _options) do
    Decimal.new(0)
  end

  defp token_balance(address_hash, block_number, token, token_id, options) do
    case Chain.get_token_balance(address_hash, token.contract_address_hash, block_number, token_id, options) do
      %{value: val} when not is_nil(val) ->
        val

      _ ->
        TokenBalanceOnDemand.trigger_historic_fetch(
          address_hash,
          token.contract_address_hash,
          token.type,
          token_id,
          block_number
        )

        Decimal.new(0)
    end
  end

  defp token_transfers_to_balances_reducer(transfer, balances, prev_block, options) do
    from = transfer.from_address
    to = transfer.to_address
    token_hash = transfer.token_contract_address_hash

    balances
    |> case do
      # from address already in the map
      %{^from => %{^token_hash => _}} = balances ->
        balances

      # we need to add from address into the map
      balances ->
        put_in(
          balances,
          Enum.map([from, token_hash], &Access.key(&1, %{})),
          token_balances(from.hash, transfer, prev_block, options)
        )
    end
    |> case do
      # to address already in the map
      %{^to => %{^token_hash => _}} = balances ->
        balances

      # we need to add to address into the map
      balances ->
        put_in(
          balances,
          Enum.map([to, token_hash], &Access.key(&1, %{})),
          token_balances(to.hash, transfer, prev_block, options)
        )
    end
  end
end
