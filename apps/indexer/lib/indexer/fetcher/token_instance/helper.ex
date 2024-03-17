defmodule Indexer.Fetcher.TokenInstance.Helper do
  @moduledoc """
    Common functions for Indexer.Fetcher.TokenInstance fetchers
  """
  alias Explorer.Chain
  alias Explorer.SmartContract.Reader
  alias Indexer.Fetcher.TokenInstance.MetadataRetriever

  require Logger

  @cryptokitties_address_hash "0x06012c8cf97bead5deae237070f9587f8e7a266d"

  @token_uri "c87b56dd"
  @base_uri "6c0360eb"
  @uri "0e89341c"

  @erc_721_1155_abi [
    %{
      "inputs" => [],
      "name" => "baseURI",
      "outputs" => [
        %{
          "internalType" => "string",
          "name" => "",
          "type" => "string"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{"type" => "string", "name" => ""}
      ],
      "name" => "tokenURI",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_tokenId"
        }
      ],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "string",
          "name" => "",
          "internalType" => "string"
        }
      ],
      "name" => "uri",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_id",
          "internalType" => "uint256"
        }
      ],
      "constant" => true
    }
  ]

  @spec batch_fetch_instances([%{}]) :: list()
  def batch_fetch_instances(token_instances) do
    token_instances =
      Enum.map(token_instances, fn
        %{contract_address_hash: hash, token_id: token_id} -> {hash, token_id}
        {_, _} = tuple -> tuple
      end)

    splitted =
      Enum.group_by(token_instances, fn {contract_address_hash, _token_id} ->
        to_string(contract_address_hash) == @cryptokitties_address_hash
      end)

    cryptokitties =
      (splitted[true] || [])
      |> Enum.map(fn {contract_address_hash, token_id} ->
        {{:ok, ["https://api.cryptokitties.co/kitties/{id}"]}, to_string(token_id), contract_address_hash, token_id}
      end)

    other = splitted[false] || []

    token_types_map =
      Enum.reduce(other, %{}, fn {contract_address_hash, _token_id}, acc ->
        address_hash_string = to_string(contract_address_hash)

        Map.put_new(acc, address_hash_string, Chain.get_token_type(contract_address_hash))
      end)

    {results, failed_results, instances_to_retry} =
      other
      |> batch_fetch_instances_inner(token_types_map, cryptokitties)
      |> Enum.reduce({[], [], []}, fn {{_task, res}, {_result, _normalized_token_id, contract_address_hash, token_id}},
                                      {results, failed_results, instances_to_retry} ->
        case res do
          {:ok, {:error, "VM execution error"} = result} ->
            add_failed_to_retry_result(
              results,
              failed_results,
              instances_to_retry,
              contract_address_hash,
              token_id,
              result
            )

          {:ok, result} ->
            {[
               result_to_insert_params(result, contract_address_hash, token_id)
               | results
             ], failed_results, instances_to_retry}

          {:exit, reason} ->
            {[
               result_to_insert_params(
                 {:error, MetadataRetriever.truncate_error("Terminated:" <> inspect(reason))},
                 contract_address_hash,
                 token_id
               )
               | results
             ], failed_results, instances_to_retry}
        end
      end)

    total_results =
      if Application.get_env(:indexer, __MODULE__)[:base_uri_retry?] do
        {success_results_from_retry, failed_results_after_retry} =
          instances_to_retry
          |> batch_fetch_instances_inner(token_types_map, [], true)
          |> Enum.reduce({[], []}, fn {{_task, res}, {_result, _normalized_token_id, contract_address_hash, token_id}},
                                      {success, failed} ->
            # credo:disable-for-next-line
            case res do
              {:ok, result} ->
                {[
                   result_to_insert_params(result, contract_address_hash, token_id)
                   | success
                 ], failed}

              {:exit, reason} ->
                {
                  success,
                  [
                    result_to_insert_params(
                      {:error, MetadataRetriever.truncate_error("Terminated:" <> inspect(reason))},
                      contract_address_hash,
                      token_id
                    )
                    | failed
                  ]
                }
            end
          end)

        results ++ success_results_from_retry ++ failed_results_after_retry
      else
        results ++ failed_results
      end

    total_results
    |> Enum.map(fn %{token_id: token_id, token_contract_address_hash: contract_address_hash} = result ->
      upsert_with_rescue(result, token_id, contract_address_hash)
    end)
  end

  defp add_failed_to_retry_result(results, failed_results, instances_to_retry, contract_address_hash, token_id, result) do
    {
      results,
      [
        result_to_insert_params(result, contract_address_hash, token_id)
        | failed_results
      ],
      [{contract_address_hash, token_id} | instances_to_retry]
    }
  end

  defp batch_fetch_instances_inner(_token_instances, _token_types_map, _cryptokitties, from_base_uri? \\ false)

  defp batch_fetch_instances_inner(token_instances, token_types_map, cryptokitties, from_base_uri?) do
    contract_results =
      (token_instances
       |> Enum.map(fn {contract_address_hash, token_id} ->
         token_id = prepare_token_id(token_id)
         contract_address_hash_string = to_string(contract_address_hash)

         prepare_request(
           token_types_map[contract_address_hash_string],
           contract_address_hash_string,
           token_id,
           from_base_uri?
         )
       end)
       |> Reader.query_contracts(@erc_721_1155_abi, [], false)
       |> Enum.zip_reduce(token_instances, [], fn result, {contract_address_hash, token_id}, acc ->
         token_id = prepare_token_id(token_id)

         [
           {result, normalize_token_id(token_types_map[to_string(contract_address_hash)], token_id),
            contract_address_hash, token_id}
           | acc
         ]
       end)
       |> Enum.reverse()) ++
        cryptokitties

    contract_results
    |> Enum.map(fn {result, normalized_token_id, _contract_address_hash, token_id} ->
      Task.async(fn -> MetadataRetriever.fetch_json(result, token_id, normalized_token_id, from_base_uri?) end)
    end)
    |> Task.yield_many(:infinity)
    |> Enum.zip(contract_results)
  end

  defp prepare_token_id(%Decimal{} = token_id), do: Decimal.to_integer(token_id)
  defp prepare_token_id(token_id), do: token_id

  defp prepare_request("ERC-721", contract_address_hash_string, token_id, from_base_uri?) do
    request = %{
      contract_address: contract_address_hash_string,
      block_number: nil
    }

    if from_base_uri? do
      request |> Map.put(:method_id, @base_uri) |> Map.put(:args, [])
    else
      request |> Map.put(:method_id, @token_uri) |> Map.put(:args, [token_id])
    end
  end

  defp prepare_request(_token_type, contract_address_hash_string, token_id, _retry) do
    %{
      contract_address: contract_address_hash_string,
      method_id: @uri,
      args: [token_id],
      block_number: nil
    }
  end

  defp normalize_token_id("ERC-721", _token_id), do: nil

  defp normalize_token_id(_token_type, token_id),
    do: token_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(64, "0")

  defp result_to_insert_params({:ok, %{metadata: metadata}}, token_contract_address_hash, token_id) do
    %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      metadata: metadata,
      error: nil
    }
  end

  defp result_to_insert_params({:error_code, code}, token_contract_address_hash, token_id),
    do: token_instance_map_with_error(token_id, token_contract_address_hash, "request error: #{code}")

  defp result_to_insert_params({:error, reason}, token_contract_address_hash, token_id),
    do: token_instance_map_with_error(token_id, token_contract_address_hash, reason)

  defp token_instance_map_with_error(token_id, token_contract_address_hash, error) do
    %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      error: error
    }
  end

  defp upsert_with_rescue(insert_params, token_id, token_contract_address_hash, retrying? \\ false) do
    Chain.upsert_token_instance(insert_params)
  rescue
    error in Postgrex.Error ->
      if retrying? do
        Logger.warn(["Failed to upsert token instance: #{inspect(error)}"], fetcher: :token_instances)
        nil
      else
        token_id
        |> token_instance_map_with_error(
          token_contract_address_hash,
          MetadataRetriever.truncate_error(inspect(error.postgres.code))
        )
        |> upsert_with_rescue(token_id, token_contract_address_hash, true)
      end
  end
end
