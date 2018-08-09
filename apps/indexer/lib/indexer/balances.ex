defmodule Indexer.Balances do
  @moduledoc """
  Extracts `Explorer.Chain.Balance` params from other schema's params
  """

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:blocks_params, blocks_params}, acc) when is_list(blocks_params) do
    # a block MUST have a miner_hash and number
    Enum.into(blocks_params, acc, fn %{miner_hash: address_hash, number: block_number}
                                     when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
  end

  defp reducer({:internal_transactions_params, internal_transactions_params}, initial)
       when is_list(internal_transactions_params) do
    Enum.reduce(internal_transactions_params, initial, &internal_transactions_params_reducer/2)
  end

  defp reducer({:logs_params, logs_params}, acc) when is_list(logs_params) do
    # a log MUST have and address_hash
    Enum.into(logs_params, acc, fn %{address_hash: address_hash, block_number: block_number}
                                   when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
  end

  defp reducer({:token_transfers_params, token_transfers_params}, initial) when is_list(token_transfers_params) do
    Enum.reduce(token_transfers_params, initial, fn %{
                                                      block_number: block_number,
                                                      from_address_hash: from_address_hash,
                                                      to_address_hash: to_address_hash,
                                                      token_contract_address_hash: token_contract_address_hash
                                                    },
                                                    acc
                                                    when is_integer(block_number) and is_binary(from_address_hash) and
                                                           is_binary(to_address_hash) and
                                                           is_binary(token_contract_address_hash) ->
      acc
      |> MapSet.put(%{address_hash: from_address_hash, block_number: block_number})
      |> MapSet.put(%{address_hash: to_address_hash, block_number: block_number})
      |> MapSet.put(%{address_hash: token_contract_address_hash, block_number: block_number})
    end)
  end

  defp reducer({:transactions_params, transactions_params}, initial) when is_list(transactions_params) do
    Enum.reduce(transactions_params, initial, &transactions_params_reducer/2)
  end

  defp internal_transactions_params_reducer(%{block_number: block_number} = internal_transaction_params, acc)
       when is_integer(block_number) do
    case internal_transaction_params do
      %{type: "call"} ->
        acc

      %{type: "create", error: _} ->
        acc

      %{type: "create", created_contract_address_hash: address_hash} when is_binary(address_hash) ->
        MapSet.put(acc, %{address_hash: address_hash, block_number: block_number})

      %{type: "suicide", from_address_hash: from_address_hash, to_address_hash: to_address_hash}
      when is_binary(from_address_hash) and is_binary(to_address_hash) ->
        acc
        |> MapSet.put(%{address_hash: from_address_hash, block_number: block_number})
        |> MapSet.put(%{address_hash: to_address_hash, block_number: block_number})
    end
  end

  defp transactions_params_reducer(
         %{block_number: block_number, from_address_hash: from_address_hash} = transaction_params,
         initial
       )
       when is_integer(block_number) and is_binary(from_address_hash) do
    # a transaction MUST have a `from_address_hash`
    acc = MapSet.put(initial, %{address_hash: from_address_hash, block_number: block_number})

    # `to_address_hash` is optional
    case transaction_params do
      %{to_address_hash: to_address_hash} when is_binary(to_address_hash) ->
        MapSet.put(acc, %{address_hash: to_address_hash, block_number: block_number})

      _ ->
        acc
    end
  end
end
