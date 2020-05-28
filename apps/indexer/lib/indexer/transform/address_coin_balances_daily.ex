defmodule Indexer.Transform.AddressCoinBalancesDaily do
  @moduledoc """
  Extracts `Explorer.Chain.Address.CoinBalanceDaily` params from other schema's params.
  """

  alias EthereumJSONRPC.Blocks

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:beneficiary_params, beneficiary_params}, acc) when is_list(beneficiary_params) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    block_numbers =
      beneficiary_params
      |> Enum.map(&Map.get(&1, :block_number))
      |> Enum.sort()
      |> Enum.dedup()

    block_timestamp_map =
      Enum.reduce(block_numbers, %{}, fn block_number, map ->
        {:ok, %Blocks{blocks_params: [%{timestamp: timestamp}]}} =
          EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)

        day = DateTime.to_date(timestamp)
        Map.put(map, "#{block_number}", day)
      end)

    Enum.into(beneficiary_params, acc, fn %{
                                            address_hash: address_hash,
                                            block_number: block_number
                                          }
                                          when is_binary(address_hash) and is_integer(block_number) ->
      day = Map.get(block_timestamp_map, "#{block_number}")

      %{address_hash: address_hash, day: day}
    end)
  end

  defp reducer({:blocks_params, blocks_params}, acc) when is_list(blocks_params) do
    # a block MUST have a miner_hash and number
    Enum.into(blocks_params, acc, fn %{miner_hash: address_hash, number: block_number, timestamp: block_timestamp}
                                     when is_binary(address_hash) and is_integer(block_number) ->
      day = DateTime.to_date(block_timestamp)
      %{address_hash: address_hash, day: day}
    end)
  end

  defp reducer({:internal_transactions_params, internal_transactions_params}, initial)
       when is_list(internal_transactions_params) do
    Enum.reduce(internal_transactions_params, initial, &internal_transactions_params_reducer/2)
  end

  defp reducer({:logs_params, logs_params}, acc) when is_list(logs_params) do
    # a log MUST have address_hash and block_number
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    block_numbers =
      logs_params
      |> Enum.map(&Map.get(&1, :block_number))
      |> Enum.sort()
      |> Enum.dedup()

    block_timestamp_map =
      Enum.reduce(block_numbers, %{}, fn block_number, map ->
        {:ok, %Blocks{blocks_params: [%{timestamp: timestamp}]}} =
          EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)

        day = DateTime.to_date(timestamp)
        Map.put(map, "#{block_number}", day)
      end)

    logs_params
    |> Enum.into(acc, fn
      %{address_hash: address_hash, block_number: block_number}
      when is_binary(address_hash) and is_integer(block_number) ->
        day = Map.get(block_timestamp_map, "#{block_number}")
        %{address_hash: address_hash, day: day}

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

  defp internal_transactions_params_reducer(
         %{block_number: block_number} = internal_transaction_params,
         acc
       )
       when is_integer(block_number) do
    case internal_transaction_params do
      %{type: "call"} ->
        acc

      %{type: "create", error: _} ->
        acc

      %{type: "create", created_contract_address_hash: address_hash} when is_binary(address_hash) ->
        json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

        {:ok, %Blocks{blocks_params: [%{timestamp: block_timestamp}]}} =
          EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)

        day = DateTime.to_date(block_timestamp)
        MapSet.put(acc, %{address_hash: address_hash, day: day})

      %{type: "selfdestruct", from_address_hash: from_address_hash, to_address_hash: to_address_hash}
      when is_binary(from_address_hash) and is_binary(to_address_hash) ->
        json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

        {:ok, %Blocks{blocks_params: [%{timestamp: block_timestamp}]}} =
          EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)

        day = DateTime.to_date(block_timestamp)

        acc
        |> MapSet.put(%{address_hash: from_address_hash, day: day})
        |> MapSet.put(%{address_hash: to_address_hash, day: day})
    end
  end

  defp transactions_params_reducer(
         %{block_number: block_number, from_address_hash: from_address_hash} = transaction_params,
         initial
       )
       when is_binary(from_address_hash) do
    # a transaction MUST have a `from_address_hash`
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    {:ok, %Blocks{blocks_params: [%{timestamp: block_timestamp}]}} =
      EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)

    day = DateTime.to_date(block_timestamp)
    acc = MapSet.put(initial, %{address_hash: from_address_hash, day: day})

    # `to_address_hash` is optional
    case transaction_params do
      %{to_address_hash: to_address_hash} when is_binary(to_address_hash) ->
        MapSet.put(acc, %{address_hash: to_address_hash, day: day})

      _ ->
        acc
    end
  end
end
