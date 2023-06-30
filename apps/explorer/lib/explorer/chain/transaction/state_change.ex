defmodule Explorer.Chain.Transaction.StateChange do
  @moduledoc """
    Helper functions and struct for storing state changes
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, TokenTransfer, Wei}
  alias Explorer.Chain.Transaction.StateChange

  defstruct [:coin_or_token_transfers, :address, :token_id, :balance_before, :balance_after, :balance_diff, :miner?]

  @type t :: %__MODULE__{
          coin_or_token_transfers: :coin | [TokenTransfer.t()],
          address: Hash.Address.t(),
          token_id: nil | non_neg_integer(),
          balance_before: Wei.t() | Decimal.t(),
          balance_after: Wei.t() | Decimal.t(),
          balance_diff: Wei.t() | Decimal.t(),
          miner?: boolean()
        }

  def coin_balances_before(tx, block_txs, from_before, to_before, miner_before) do
    block = tx.block

    block_txs
    |> Enum.reduce_while(
      {from_before, to_before, miner_before},
      fn block_tx, {block_from, block_to, block_miner} = state ->
        if block_tx.index < tx.index do
          {:cont,
           {update_coin_balance_from_tx(tx.from_address_hash, block_tx, block_from, block),
            update_coin_balance_from_tx(tx.to_address_hash, block_tx, block_to, block),
            update_coin_balance_from_tx(tx.block.miner_hash, block_tx, block_miner, block)}}
        else
          # txs ordered by index ascending, so we can halt after facing index greater or equal than index of our tx
          {:halt, state}
        end
      end
    )
  end

  def update_coin_balance_from_tx(address_hash, tx, balance, block) do
    from = tx.from_address_hash
    to = tx.to_address_hash
    miner = block.miner_hash

    balance
    |> (&if(address_hash == from, do: Wei.sub(&1, from_loss(tx)), else: &1)).()
    |> (&if(address_hash == to, do: Wei.sum(&1, to_profit(tx)), else: &1)).()
    |> (&if(address_hash == miner, do: Wei.sum(&1, miner_profit(tx, block)), else: &1)).()
  end

  def token_balances_before(balances_before, tx, block_txs) do
    block_txs
    |> Enum.reduce_while(
      balances_before,
      fn block_tx, state ->
        if block_tx.index < tx.index do
          {:cont, do_update_token_balances_from_token_transfers(block_tx.token_transfers, state)}
        else
          # txs ordered by index ascending, so we can halt after facing index greater or equal than index of our tx
          {:halt, state}
        end
      end
    )
  end

  def do_update_token_balances_from_token_transfers(
        token_transfers,
        balances_map,
        include_transfers \\ :no
      ) do
    Enum.reduce(
      token_transfers,
      balances_map,
      &token_transfers_balances_reducer(&1, &2, include_transfers)
    )
  end

  defp token_transfers_balances_reducer(transfer, state_balances_map, include_transfers) do
    from = transfer.from_address
    to = transfer.to_address
    token = transfer.token_contract_address_hash

    state_balances_map
    |> case do
      # from address is needed to be updated in our map
      %{^from => %{^token => values}} = balances_map ->
        put_in(
          balances_map,
          Enum.map([from, token], &Access.key(&1, %{})),
          do_update_balance(values, :from, transfer, include_transfers)
        )

      # we are not interested in this address
      balances_map ->
        balances_map
    end
    |> case do
      # to address is needed to be updated in our map
      %{^to => %{^token => values}} = balances_map ->
        put_in(
          balances_map,
          Enum.map([to, token], &Access.key(&1, %{})),
          do_update_balance(values, :to, transfer, include_transfers)
        )

      # we are not interested in this address
      balances_map ->
        balances_map
    end
  end

  # point of this function is to include all transfers for frontend if option :include_transfer is passed
  defp do_update_balance(old_val, type, transfer, :include_transfers) do
    old_val_with_transfer =
      Map.update(old_val, :transfers, [{type, transfer}], fn transfers -> [{type, transfer} | transfers] end)

    do_update_balance(old_val_with_transfer, type, transfer, :no)
  end

  defp do_update_balance(old_val, type, transfer, _) do
    token_ids = if transfer.token.type == "ERC-1155", do: transfer.token_ids || [transfer.token_id], else: [nil]
    transfer_amounts = transfer.amounts || [transfer.amount || 1]

    sub_or_add =
      case type do
        :from -> &Decimal.sub/2
        :to -> &Decimal.add/2
      end

    token_ids
    |> Stream.zip(transfer_amounts)
    |> Enum.reduce(old_val, fn {id, amount}, ids_to_balances ->
      case ids_to_balances do
        %{^id => val} -> %{ids_to_balances | id => sub_or_add.(val, amount)}
        _ -> ids_to_balances
      end
    end)
  end

  def from_loss(tx) do
    {_, fee} = Chain.fee(tx, :wei)

    if error?(tx) do
      %Wei{value: fee}
    else
      Wei.sum(tx.value, %Wei{value: fee})
    end
  end

  def to_profit(tx) do
    if error?(tx) do
      %Wei{value: 0}
    else
      tx.value
    end
  end

  defp miner_profit(tx, block) do
    base_fee_per_gas = block.base_fee_per_gas || %Wei{value: Decimal.new(0)}
    max_priority_fee_per_gas = tx.max_priority_fee_per_gas || tx.gas_price
    max_fee_per_gas = tx.max_fee_per_gas || tx.gas_price

    priority_fee_per_gas =
      Enum.min_by([max_priority_fee_per_gas, Wei.sub(max_fee_per_gas, base_fee_per_gas)], fn x ->
        Wei.to(x, :wei)
      end)

    Wei.mult(priority_fee_per_gas, tx.gas_used)
  end

  defp error?(tx) do
    case Chain.transaction_to_status(tx) do
      {:error, _} -> true
      _ -> false
    end
  end

  def has_diff?(%Wei{value: val}) do
    not Decimal.eq?(val, Decimal.new(0))
  end

  def has_diff?(val) do
    not Decimal.eq?(val, Decimal.new(0))
  end

  def state_change(address, balance_before, balance_after, miner? \\ true) do
    %StateChange{
      coin_or_token_transfers: :coin,
      address: address,
      balance_before: balance_before,
      balance_after: balance_after,
      balance_diff: balance_after |> Wei.sub(balance_before),
      miner?: miner?
    }
  end

  def native_coin_entries(transaction, from_before_tx, to_before_tx, miner_before_tx) do
    block = transaction.block

    from_hash = transaction.from_address_hash
    to_hash = transaction.to_address_hash
    miner_hash = block.miner_hash

    from_coin_entry =
      if from_hash not in [to_hash, miner_hash] do
        from = transaction.from_address
        from_after_tx = update_coin_balance_from_tx(from_hash, transaction, from_before_tx, block)
        coin_entry(from, from_before_tx, from_after_tx)
      end

    to_coin_entry =
      if not is_nil(to_hash) and to_hash != miner_hash do
        to = transaction.to_address
        to_after = update_coin_balance_from_tx(to_hash, transaction, to_before_tx, block)
        coin_entry(to, to_before_tx, to_after)
      end

    miner = block.miner
    miner_after = update_coin_balance_from_tx(miner_hash, transaction, miner_before_tx, block)
    miner_entry = coin_entry(miner, miner_before_tx, miner_after, true)

    [from_coin_entry, to_coin_entry, miner_entry] |> Enum.reject(&is_nil/1)
  end

  defp coin_entry(address, balance_before, balance_after, miner? \\ false) do
    diff = Wei.sub(balance_after, balance_before)

    if has_diff?(diff) do
      %StateChange{
        coin_or_token_transfers: :coin,
        address: address,
        token_id: nil,
        balance_before: balance_before,
        balance_after: balance_after,
        balance_diff: diff,
        miner?: miner?
      }
    end
  end

  def token_entries(token_transfers, token_balances_before) do
    token_balances_after =
      do_update_token_balances_from_token_transfers(
        token_transfers,
        token_balances_before,
        :include_transfers
      )

    for {address, token_balances} <- token_balances_after,
        {token_hash, id_balances_with_transfers} <- token_balances,
        {%{transfers: transfers}, id_balances} = Map.split(id_balances_with_transfers, [:transfers]),
        {id, balance} <- id_balances do
      balance_before = token_balances_before[address][token_hash][id]
      balance_diff = Decimal.sub(balance, balance_before)
      transfer = elem(List.first(transfers), 1)

      if transfer.token.type != "ERC-20" or has_diff?(balance_diff) do
        %StateChange{
          coin_or_token_transfers: transfers,
          address: address,
          token_id: id,
          balance_before: balance_before,
          balance_after: balance,
          balance_diff: balance_diff,
          miner?: false
        }
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn state_change -> to_string(state_change.address && state_change.address.hash) end)
  end
end
