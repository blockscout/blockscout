defmodule BlockScoutWeb.Models.TransactionStateHelper do
  @moduledoc """
    Transaction state changes related functions
  """

  alias Explorer.Chain.Transaction.StateChange
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Block, Transaction, Wei}
  alias Indexer.Fetcher.{CoinBalance, TokenBalance}

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def state_changes(%Transaction{block: %Block{} = block} = transaction) do
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
      paging_options: %PagingOptions{key: nil, page_size: nil}
    ]

    token_transfers = Chain.transaction_to_token_transfers(transaction_hash, full_options)

    block_txs =
      Chain.block_to_transactions(block.hash,
        necessity_by_association: %{},
        paging_options: %PagingOptions{key: nil, page_size: nil}
      )

    from_before_block = coin_balance(transaction.from_address_hash, block.number - 1)
    to_before_block = coin_balance(transaction.to_address_hash, block.number - 1)
    miner_before_block = coin_balance(block.miner_hash, block.number - 1)

    {from_before_tx, to_before_tx, miner_before_tx} =
      StateChange.coin_balances_before(transaction, block_txs, from_before_block, to_before_block, miner_before_block)

    native_coin_entries =
      StateChange.native_coin_entries(transaction, from_before_tx, to_before_tx, miner_before_tx)
      |> IO.inspect(label: "native state changes")

    token_balances_before =
      token_transfers
      |> Enum.reduce(%{}, &token_transfers_to_balances_reducer/2)
      |> StateChange.token_balances_before(transaction, block_txs)

    tokens_entries =
      StateChange.token_entries(token_transfers, token_balances_before) |> IO.inspect(label: "token state changes")

    native_coin_entries ++ tokens_entries
  end

  def state_changes(_transaction), do: []

  defp coin_balance(address_hash, _block_number) when is_nil(address_hash) do
    %Wei{value: Decimal.new(0)}
  end

  defp coin_balance(address_hash, block_number) do
    case Chain.get_coin_balance(address_hash, block_number) do
      %{value: val} when not is_nil(val) ->
        val

      _ ->
        CoinBalance.async_fetch_balances([%{address_hash: address_hash, block_number: block_number}])
        %Wei{value: Decimal.new(0)}
    end
  end

  defp token_balances(address_hash, token_transfer, block_number) do
    token = token_transfer.token

    token_ids =
      if token.type == "ERC-1155" do
        token_transfer.token_ids || [token_transfer.token_id]
      else
        [nil]
      end

    Enum.into(token_ids, %{transfers: []}, &{&1, token_balance(address_hash, block_number, token, &1)})
  end

  defp token_balance(@burn_address_hash, _block_number, _token, _token_id) do
    Decimal.new(0)
  end

  defp token_balance(address_hash, block_number, token, token_id) do
    case Chain.get_token_balance(address_hash, token.contract_address_hash, block_number, token_id) do
      %{value: val} when not is_nil(val) ->
        val

      _ ->
        TokenBalance.async_fetch([
          %{
            token_contract_address_hash: token.contract_address_hash,
            address_hash: address_hash,
            block_number: block_number,
            token_type: token.type,
            token_id: token_id
          }
        ])

        Decimal.new(0)
    end
  end

  defp token_transfers_to_balances_reducer(transfer, balances) do
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
          token_balances(from.hash, transfer, prev_block)
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
          token_balances(to.hash, transfer, prev_block)
        )
    end
  end
end
