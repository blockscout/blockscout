defmodule Indexer.Fetcher.TokenInstance.Helper do
  @moduledoc """
    Common functions for Indexer.Fetcher.TokenInstance fetchers
  """
  alias Explorer.Chain
  alias Explorer.SmartContract.Reader
  alias Indexer.Fetcher.TokenInstance.MetadataRetriever

  @cryptokitties_address_hash "0x06012c8cf97bead5deae237070f9587f8e7a266d"

  @token_uri "c87b56dd"
  @uri "0e89341c"

  @erc_721_1155_abi [
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

    contract_results =
      (other
       |> Enum.map(fn {contract_address_hash, token_id} ->
         token_id = prepare_token_id(token_id)
         contract_address_hash_string = to_string(contract_address_hash)

         prepare_request(token_types_map[contract_address_hash_string], contract_address_hash_string, token_id)
       end)
       |> Reader.query_contracts(@erc_721_1155_abi, [], false)
       |> Enum.zip_reduce(other, [], fn result, {contract_address_hash, token_id}, acc ->
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
    |> Enum.map(fn {result, normalized_token_id, _contract_address_hash, _token_id} ->
      Task.async(fn -> MetadataRetriever.fetch_json(result, normalized_token_id) end)
    end)
    |> Task.yield_many(:infinity)
    |> Enum.zip(contract_results)
    |> Enum.map(fn {{_task, res}, {_result, _normalized_token_id, contract_address_hash, token_id}} ->
      case res do
        {:ok, result} ->
          result_to_insert_params(result, contract_address_hash, token_id)

        {:exit, reason} ->
          result_to_insert_params(
            {:error, MetadataRetriever.truncate_error("Terminated:" <> inspect(reason))},
            contract_address_hash,
            token_id
          )
      end
    end)
    |> Chain.upsert_token_instances_list()
  end

  defp prepare_token_id(%Decimal{} = token_id), do: Decimal.to_integer(token_id)
  defp prepare_token_id(token_id), do: token_id

  defp prepare_request("ERC-721", contract_address_hash_string, token_id) do
    %{
      contract_address: contract_address_hash_string,
      method_id: @token_uri,
      args: [token_id],
      block_number: nil
    }
  end

  defp prepare_request(_token_type, contract_address_hash_string, token_id) do
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
end
