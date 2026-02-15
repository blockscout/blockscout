defmodule Explorer.Chain.Transaction.StateChange do
  @moduledoc """
    Helper functions and struct for storing state changes
  """

  use Utils.RuntimeEnvHelper,
    miner_gets_burnt_fees?: [:explorer, [Explorer.Chain.Transaction, :block_miner_gets_burnt_fees?]]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Hash, InternalTransaction, TokenTransfer, Transaction, Wei}
  alias Explorer.Chain.Transaction.StateChange

  defstruct [:coin_or_token_transfers, :address, :token_id, :balance_before, :balance_after, :balance_diff, :miner?]

  @type t :: %__MODULE__{
          coin_or_token_transfers: :coin | [TokenTransfer.t()],
          address: Address.t(),
          token_id: nil | non_neg_integer(),
          balance_before: Wei.t() | Decimal.t(),
          balance_after: Wei.t() | Decimal.t(),
          balance_diff: Wei.t() | Decimal.t(),
          miner?: boolean()
        }

  @type coin_balances_map :: %{Hash.Address.t() => {Address.t(), Wei.t()}}

  @spec coin_balances_before(Transaction.t(), [Transaction.t()], coin_balances_map()) :: coin_balances_map()
  def coin_balances_before(transaction, block_transactions, coin_balances_before_block) do
    block = transaction.block

    block_transactions
    |> Enum.reduce_while(
      coin_balances_before_block,
      fn block_transaction, acc ->
        if block_transaction.index < transaction.index do
          {:cont, update_coin_balances_from_transaction(acc, block_transaction, block)}
        else
          # transactions ordered by index ascending, so we can halt after facing index greater or equal than index of our transaction
          {:halt, acc}
        end
      end
    )
  end

  @spec update_coin_balances_from_transaction(coin_balances_map(), Transaction.t(), Block.t()) :: coin_balances_map()
  def update_coin_balances_from_transaction(coin_balances, transaction, block) do
    coin_balances =
      coin_balances
      |> update_balance(transaction.from_address_hash, &Wei.sub(&1, from_loss(transaction)))
      |> update_balance(transaction.to_address_hash, &Wei.sum(&1, to_profit(transaction)))
      |> update_balance(block.miner_hash, &Wei.sum(&1, miner_profit(transaction, block)))

    if error?(transaction) do
      coin_balances
    else
      transaction.internal_transactions
      |> Enum.reduce(coin_balances, &update_coin_balances_from_internal_transaction(&1, &2))
    end
  end

  defp update_coin_balances_from_internal_transaction(
         %InternalTransaction{call_type: call_type, call_type_enum: call_type_enum},
         coin_balances
       )
       when :delegatecall in [call_type, call_type_enum],
       do: coin_balances

  defp update_coin_balances_from_internal_transaction(%InternalTransaction{index: 0}, coin_balances), do: coin_balances

  defp update_coin_balances_from_internal_transaction(internal_transaction, coin_balances) do
    coin_balances
    |> update_balance(internal_transaction.from_address_hash, &Wei.sub(&1, from_loss(internal_transaction)))
    |> update_balance(internal_transaction.to_address_hash, &Wei.sum(&1, to_profit(internal_transaction)))
  end

  def token_balances_before(balances_before, transaction, block_transactions) do
    block_transactions
    |> Enum.reduce_while(
      balances_before,
      fn block_transaction, state ->
        if block_transaction.index < transaction.index do
          {:cont, do_update_token_balances_from_token_transfers(block_transaction.token_transfers, state)}
        else
          # transactions ordered by index ascending, so we can halt after facing index greater or equal than index of our transaction
          {:halt, state}
        end
      end
    )
  end

  defp do_update_token_balances_from_token_transfers(
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
    # Skip ERC-7984 (confidential) transfers - we can't track encrypted balances
    if transfer.token && transfer.token.type == "ERC-7984" do
      state_balances_map
    else
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
  end

  # point of this function is to include all transfers for frontend if option :include_transfer is passed
  defp do_update_balance(old_val, type, transfer, :include_transfers) do
    old_val_with_transfer =
      Map.update(old_val, :transfers, [{type, transfer}], fn transfers -> [{type, transfer} | transfers] end)

    do_update_balance(old_val_with_transfer, type, transfer, :no)
  end

  defp do_update_balance(old_val, type, transfer, _) do
    token_ids = if transfer.token.type == "ERC-1155", do: transfer.token_ids, else: [nil]
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

  @doc """
  Returns the balance change of from address of a transaction
  or an internal transaction.
  """
  @spec from_loss(Transaction.t() | InternalTransaction.t()) :: Wei.t()
  def from_loss(%Transaction{} = transaction) do
    {_, fee} = Transaction.fee(transaction, :wei)

    if error?(transaction) do
      %Wei{value: fee}
    else
      Wei.sum(transaction.value, %Wei{value: fee})
    end
  end

  def from_loss(%InternalTransaction{} = transaction) do
    transaction.value
  end

  @doc """
  Returns the balance change of to address of a transaction
  or an internal transaction.
  """
  @spec to_profit(Transaction.t() | InternalTransaction.t()) :: Wei.t()
  def to_profit(%Transaction{} = transaction) do
    if error?(transaction) do
      %Wei{value: 0}
    else
      transaction.value
    end
  end

  def to_profit(%InternalTransaction{} = transaction) do
    transaction.value
  end

  # Calculates block miner profit for the given transaction.
  #
  # Typically that is priority fee, but if `BLOCK_MINER_GETS_BURNT_FEES` is enabled,
  # the profit is the sum of the priority fee and the fee which would be burnt.
  #
  # ## Parameters
  # - `transaction`: The transaction entity containing info needed to calculate the profit.
  # - `block`: The block entity containing info needed to calculate the profit.
  #
  # ## Returns
  # - The miner profit amount in Wei.
  @spec miner_profit(Transaction.t(), Block.t()) :: Wei.t()
  defp miner_profit(transaction, block) do
    base_fee_per_gas = block.base_fee_per_gas || Wei.zero()
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas || transaction.gas_price
    max_fee_per_gas = transaction.max_fee_per_gas || transaction.gas_price

    priority_fee_per_gas =
      Enum.min_by([max_priority_fee_per_gas, Wei.sub(max_fee_per_gas, base_fee_per_gas)], fn x ->
        Wei.to(x, :wei)
      end)

    burnt_fees_for_miner =
      case miner_gets_burnt_fees?() && Transaction.burnt_fees(transaction.gas_used, max_fee_per_gas, base_fee_per_gas) do
        false -> Wei.zero()
        nil -> Wei.zero()
        value -> value
      end

    priority_fee_per_gas
    |> Wei.mult(transaction.gas_used)
    |> Wei.sum(burnt_fees_for_miner)
  end

  defp error?(transaction) do
    case Chain.transaction_to_status(transaction) do
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

  @doc """
  Returns the list of native coin state changes of a transaction, including state changes from the internal transactions,
  taking into account state changes from previous transactions in the same block.
  """
  @spec native_coin_entries(Transaction.t(), coin_balances_map()) :: [t()]
  def native_coin_entries(transaction, coin_balances_before_transaction) do
    block = transaction.block

    coin_balances_after_transaction =
      update_coin_balances_from_transaction(coin_balances_before_transaction, transaction, block)

    coin_balances_before_transaction
    |> Enum.reduce([], fn {address_hash, {address, coin_balance_before}}, acc ->
      {_, coin_balance_after} = coin_balances_after_transaction[address_hash]
      coin_entry = coin_entry(address, coin_balance_before, coin_balance_after, address_hash == block.miner_hash)

      if coin_entry do
        [coin_entry | acc]
      else
        acc
      end
    end)
  end

  defp coin_entry(address, balance_before, balance_after, miner?) do
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

  defp update_balance(coin_balances, address_hash, _update_function) when is_nil(address_hash),
    do: coin_balances

  defp update_balance(coin_balances, address_hash, update_function) do
    if Map.has_key?(coin_balances, address_hash) do
      Map.update(coin_balances, address_hash, Wei.zero(), fn {address, balance} ->
        {address, update_function.(balance)}
      end)
    else
      coin_balances
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

      if transfer.token.type not in ["ERC-20", "ZRC-2"] or has_diff?(balance_diff) do
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
