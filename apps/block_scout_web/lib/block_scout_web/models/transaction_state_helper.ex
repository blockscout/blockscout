defmodule BlockScoutWeb.Models.TransactionStateHelper do
  @moduledoc """
    Transaction state changes related functions
  """

  import BlockScoutWeb.Chain, only: [default_paging_options: 0]
  alias Explorer.Chain.Transaction.StateChange
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Block, Transaction, Wei}
  alias Explorer.Chain.Cache.StateChanges
  alias Indexer.Fetcher.{CoinBalanceOnDemand, TokenBalanceOnDemand}

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def state_changes(transaction, options \\ [])

  def state_changes(%Transaction{block: %Block{}} = transaction, options) do
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

  defp do_state_changes(%Transaction{block: %Block{} = block} = transaction, options) do
    transaction_hash = transaction.hash

    full_options = [
      necessity_by_association: %{
        [from_address: :smart_contract] => :optional,
        [to_address: :smart_contract] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional,
        from_address: :required,
        to_address: :required
      },
      # we need to consider all token transfers in block to show whole state change of transaction
      paging_options: %PagingOptions{key: nil, page_size: nil},
      api?: Keyword.get(options, :api?, false)
    ]

    token_transfers = Chain.transaction_to_token_transfers(transaction_hash, full_options)

    block_txs =
      Chain.block_to_transactions(block.hash,
        necessity_by_association: %{},
        paging_options: %PagingOptions{key: nil, page_size: nil},
        api?: Keyword.get(options, :api?, false)
      )

    from_before_block = coin_balance(transaction.from_address_hash, block.number - 1, options)
    to_before_block = coin_balance(transaction.to_address_hash, block.number - 1, options)
    miner_before_block = coin_balance(block.miner_hash, block.number - 1, options)

    {from_before_tx, to_before_tx, miner_before_tx} =
      StateChange.coin_balances_before(transaction, block_txs, from_before_block, to_before_block, miner_before_block)

    native_coin_entries = StateChange.native_coin_entries(transaction, from_before_tx, to_before_tx, miner_before_tx)

    token_balances_before =
      token_transfers
      |> Enum.reduce(%{}, &token_transfers_to_balances_reducer(&1, &2, options))
      |> StateChange.token_balances_before(transaction, block_txs)

    tokens_entries = StateChange.token_entries(token_transfers, token_balances_before)

    native_coin_entries ++ tokens_entries
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
        token_transfer.token_ids || [token_transfer.token_id]
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

  defp token_transfers_to_balances_reducer(transfer, balances, options) do
    from = transfer.from_address
    to = transfer.to_address
    token_hash = transfer.token_contract_address_hash
    prev_block = transfer.block_number - 1

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
