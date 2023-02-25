defmodule BlockScoutWeb.Models.TransactionStateHelper do
  @moduledoc """
    Module includes functions needed for BlockScoutWeb.TransactionStateController
  """

  alias Explorer.{Chain, Chain.Wei, PagingOptions}
  alias Explorer.Chain
  alias Explorer.Chain.Transaction.StateChange
  alias Indexer.Fetcher.{CoinBalance, TokenBalance}

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

  @burn_address_hash burn_address_hash

  def state_changes(transaction) do
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

    block = transaction.block

    block_txs =
      Chain.block_to_transactions(block.hash,
        necessity_by_association: %{},
        paging_options: %PagingOptions{key: nil, page_size: nil}
      )

    {from_before, to_before, miner_before} = coin_balances_before(transaction, block_txs)

    from_hash = transaction.from_address_hash
    to_hash = transaction.to_address_hash
    miner_hash = block.miner_hash

    from_coin_entry =
      if from_hash not in [to_hash, miner_hash] do
        from = transaction.from_address
        from_after = do_update_coin_balance_from_tx(from_hash, transaction, from_before, block)
        balance_diff = Wei.sub(from_after, from_before)

        if has_diff?(balance_diff) do
          %StateChange{
            coin_or_token_transfers: :coin,
            address: from,
            balance_before: from_before,
            balance_after: from_after,
            balance_diff: balance_diff,
            miner?: false
          }
        end
      end

    to_coin_entry =
      if not is_nil(to_hash) and to_hash != miner_hash do
        to = transaction.to_address
        to_after = do_update_coin_balance_from_tx(to_hash, transaction, to_before, block)
        balance_diff = Wei.sub(to_after, to_before)

        if has_diff?(balance_diff) do
          %StateChange{
            coin_or_token_transfers: :coin,
            address: to,
            balance_before: to_before,
            balance_after: to_after,
            balance_diff: balance_diff,
            miner?: false
          }
        end
      end

    miner = block.miner
    miner_after = do_update_coin_balance_from_tx(miner_hash, transaction, miner_before, block)
    miner_diff = Wei.sub(miner_after, miner_before)

    miner_entry =
      if has_diff?(miner_diff) do
        %StateChange{
          coin_or_token_transfers: :coin,
          address: miner,
          balance_before: miner_before,
          balance_after: miner_after,
          balance_diff: miner_diff,
          miner?: true
        }
      end

    token_balances_before = token_balances_before(token_transfers, transaction, block_txs)

    token_balances_after =
      do_update_token_balances_from_token_transfers(
        token_transfers,
        token_balances_before,
        :include_transfers
      )

    items =
      for {address, balances} <- token_balances_after,
          {token_hash, {balance, transfers}} <- balances do
        balance_before = token_balances_before[address][token_hash]
        balance_diff = Decimal.sub(balance, balance_before)
        transfer = elem(List.first(transfers), 1)

        if transfer.token.type != "ERC-20" or has_diff?(balance_diff) do
          %StateChange{
            coin_or_token_transfers: transfers,
            address: address,
            balance_before: balance_before,
            balance_after: balance,
            balance_diff: balance_diff,
            miner?: false
          }
        end
      end

    [from_coin_entry, to_coin_entry, miner_entry | items]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn state_change -> to_string(state_change.address && state_change.address.hash) end)
  end

  defp coin_balance(address_hash, _block_number) when is_nil(address_hash) do
    %Wei{value: Decimal.new(0)}
  end

  defp coin_balance(address_hash, block_number) do
    case Chain.get_coin_balance(address_hash, block_number) do
      %{value: val} when not is_nil(val) ->
        val

      _ ->
        json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
        CoinBalance.run([{address_hash.bytes, block_number}], json_rpc_named_arguments)
        # after CoinBalance.run balance is fetched and imported, so we can call coin_balance again
        coin_balance(address_hash, block_number)
    end
  end

  defp coin_balances_before(tx, block_txs) do
    block = tx.block

    from_before = coin_balance(tx.from_address_hash, block.number - 1)
    to_before = coin_balance(tx.to_address_hash, block.number - 1)
    miner_before = coin_balance(block.miner_hash, block.number - 1)

    block_txs
    |> Enum.reduce_while(
      {from_before, to_before, miner_before},
      fn block_tx, {block_from, block_to, block_miner} = state ->
        if block_tx.index < tx.index do
          {:cont,
           {do_update_coin_balance_from_tx(tx.from_address_hash, block_tx, block_from, block),
            do_update_coin_balance_from_tx(tx.to_address_hash, block_tx, block_to, block),
            do_update_coin_balance_from_tx(tx.block.miner_hash, block_tx, block_miner, block)}}
        else
          # txs ordered by index ascending, so we can halt after facing index greater or equal than index of our tx
          {:halt, state}
        end
      end
    )
  end

  defp do_update_coin_balance_from_tx(address_hash, tx, balance, block) do
    from = tx.from_address_hash
    to = tx.to_address_hash
    miner = block.miner_hash

    balance
    |> (&if(address_hash == from, do: Wei.sub(&1, from_loss(tx)), else: &1)).()
    |> (&if(address_hash == to, do: Wei.sum(&1, to_profit(tx)), else: &1)).()
    |> (&if(address_hash == miner, do: Wei.sum(&1, miner_profit(tx, block)), else: &1)).()
  end

  defp token_balance(@burn_address_hash, _token_transfer, _block_number) do
    Decimal.new(0)
  end

  defp token_balance(address_hash, token_transfer, block_number, retry? \\ false) do
    token = token_transfer.token
    token_contract_address_hash = token.contract_address_hash

    case Chain.get_token_balance(address_hash, token_contract_address_hash, block_number) do
      %{value: val} when not is_nil(val) ->
        val

      # we haven't fetched this balance yet
      _ ->
        if retry? do
          Decimal.new(0)
        else
          json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

          token_id_int =
            case token_transfer.token_id do
              %Decimal{} -> Decimal.to_integer(token_transfer.token_id)
              id_int when is_integer(id_int) -> id_int
              _ -> token_transfer.token_id
            end

          TokenBalance.run(
            [
              {address_hash.bytes, token_contract_address_hash.bytes, block_number, token.type, token_id_int, 0}
            ],
            json_rpc_named_arguments
          )

          # after TokenBalance.run balance is fetched and imported, so we can call token_balance again
          token_balance(address_hash, token_transfer, block_number, true)
        end
    end
  end

  defp token_balances_before(token_transfers, tx, block_txs) do
    balances_before =
      token_transfers
      |> Enum.reduce(%{}, fn transfer, balances_map ->
        from = transfer.from_address
        to = transfer.to_address
        token_hash = transfer.token_contract_address_hash
        prev_block = transfer.block_number - 1

        balances_with_from =
          case balances_map do
            # from address already in the map
            %{^from => %{^token_hash => _}} ->
              balances_map

            # we need to add from address into the map
            _ ->
              put_in(
                balances_map,
                Enum.map([from, token_hash], &Access.key(&1, %{})),
                token_balance(from.hash, transfer, prev_block)
              )
          end

        case balances_with_from do
          # to address already in the map
          %{^to => %{^token_hash => _}} ->
            balances_with_from

          # we need to add to address into the map
          _ ->
            put_in(
              balances_with_from,
              Enum.map([to, token_hash], &Access.key(&1, %{})),
              token_balance(to.hash, transfer, prev_block)
            )
        end
      end)

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
    from = transfer.from_address
    to = transfer.to_address
    token = transfer.token_contract_address_hash

    balances_map_from_included =
      case state_balances_map do
        # from address is needed to be updated in our map
        %{^from => %{^token => val}} ->
          put_in(
            state_balances_map,
            Enum.map([from, token], &Access.key(&1, %{})),
            do_update_balance(val, :from, transfer, include_transfers)
          )

        # we are not interested in this address
        _ ->
          state_balances_map
      end

    case balances_map_from_included do
      # to address is needed to be updated in our map
      %{^to => %{^token => val}} ->
        put_in(
          balances_map_from_included,
          Enum.map([to, token], &Access.key(&1, %{})),
          do_update_balance(val, :to, transfer, include_transfers)
        )

      # we are not interested in this address
      _ ->
        balances_map_from_included
    end
  end

  # point of this function is to include all transfers for frontend if option :include_transfer is passed
  defp do_update_balance(old_val, type, transfer, include_transfers) do
    transfer_amount = if is_nil(transfer.amount), do: 1, else: transfer.amount

    case {include_transfers, old_val, type} do
      {:include_transfers, {val, transfers}, :from} ->
        {Decimal.sub(val, transfer_amount), [{type, transfer} | transfers]}

      {:include_transfers, {val, transfers}, :to} ->
        {Decimal.add(val, transfer_amount), [{type, transfer} | transfers]}

      {:include_transfers, val, :from} ->
        {Decimal.sub(val, transfer_amount), [{type, transfer}]}

      {:include_transfers, val, :to} ->
        {Decimal.add(val, transfer_amount), [{type, transfer}]}

      {_, val, :from} ->
        Decimal.sub(val, transfer_amount)

      {_, val, :to} ->
        Decimal.add(val, transfer_amount)
    end
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
end
