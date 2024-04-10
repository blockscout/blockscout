defmodule Indexer.Transform.AddressCoinBalances do
  @moduledoc """
  Extracts `Explorer.Chain.Address.CoinBalance` params from other schema's params.
  """

  alias Explorer.Chain.TokenTransfer
  alias Explorer.Chain.Cache.CeloCoreContracts

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:beneficiary_params, beneficiary_params}, acc) when is_list(beneficiary_params) do
    Enum.into(beneficiary_params, acc, fn %{address_hash: address_hash, block_number: block_number}
                                          when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
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
    # a log MUST have address_hash and block_number
    logs_params
    |> Enum.reject(
      &(&1.first_topic == TokenTransfer.constant() or
          &1.first_topic == TokenTransfer.erc1155_single_transfer_signature() or
          &1.first_topic == TokenTransfer.erc1155_batch_transfer_signature())
    )
    |> Enum.into(acc, fn
      %{address_hash: address_hash, block_number: block_number}
      when is_binary(address_hash) and is_integer(block_number) ->
        %{address_hash: address_hash, block_number: block_number}

      %{type: "pending"} ->
        nil
    end)
    |> Enum.reject(fn val -> is_nil(val) end)
    |> MapSet.new()
  end

  defp reducer({:transactions_params, transactions_params}, initial) when is_list(transactions_params) do
    Enum.reduce(transactions_params, initial, &transactions_params_reducer/2)
  end

  defp reducer({:block_second_degree_relations_params, block_second_degree_relations_params}, initial)
       when is_list(block_second_degree_relations_params),
       do: initial

  defp reducer({:withdrawals, withdrawals}, acc) when is_list(withdrawals) do
    Enum.into(withdrawals, acc, fn %{address_hash: address_hash, block_number: block_number}
                                   when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
  end

  if Application.compile_env(:explorer, :chain_type) == "celo" do
    defp reducer({:celo_token_transfers, token_transfers}, acc) when is_list(token_transfers) do
      celo_token_contract_address_hash = CeloCoreContracts.get_celo_token_address()

      token_transfers
      |> Enum.filter(fn %{token_contract_address_hash: contract} ->
        contract == celo_token_contract_address_hash
      end)
      |> Enum.reduce(acc, &celo_token_transfers_params_reducer/2)
    end

    defp celo_token_transfers_params_reducer(
           %{
             from_address_hash: from_address_hash,
             to_address_hash: to_address_hash,
             block_number: block_number
           },
           acc
         )
         when is_binary(from_address_hash) and is_binary(to_address_hash) and is_integer(block_number) do
      acc
      |> MapSet.put(%{address_hash: from_address_hash, block_number: block_number})
      |> MapSet.put(%{address_hash: to_address_hash, block_number: block_number})
    end
  else
    defp reducer({:celo_token_transfers, token_transfers}, acc) when is_list(token_transfers) do
      acc
    end
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

      %{type: "selfdestruct", from_address_hash: from_address_hash, to_address_hash: to_address_hash}
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
    acc =
      case transaction_params do
        %{to_address_hash: to_address_hash} when is_binary(to_address_hash) ->
          MapSet.put(acc, %{address_hash: to_address_hash, block_number: block_number})

        _ ->
          acc
      end

    transactions_params_chain_type_fields_reducer(transaction_params, acc)
  end

  # todo: subject for deprecation, since celo transactions with
  # gatewayFeeRecipient are deprecated
  defp transactions_params_chain_type_fields_reducer(
         %{
           block_number: block_number,
           gas_fee_recipient_address_hash: recipient_address_hash,
           gas_token_contract_address_hash: nil
         },
         initial
       )
       when is_integer(block_number) and is_binary(recipient_address_hash) and
              recipient_address_hash != "0x0000000000000000000000000000000000000000" do
    if Application.get_env(:explorer, :chain_type) == "celo" do
      MapSet.put(initial, %{address_hash: recipient_address_hash, block_number: block_number})
    else
      initial
    end
  end

  defp transactions_params_chain_type_fields_reducer(_, acc), do: acc
end
