defmodule Indexer.Fetcher.TokenInstance.Helper do
  @moduledoc """
    Common functions for Indexer.Fetcher.TokenInstance fetchers
  """

  alias EthereumJSONRPC.NFT
  alias Explorer.Chain
  alias Explorer.Chain.Token.Instance
  alias Explorer.Token.MetadataRetriever
  alias Indexer.NFTMediaHandler.Queue

  require Logger

  @cryptokitties_address_hash "0x06012c8cf97bead5deae237070f9587f8e7a266d"

  @doc """
  Fetches and upserts a batch of token instances.

  This function takes a list of `token_instances`, prepares the parameters for insertion,
  and attempts to upsert them into the database. If an error occurs during the upsert,
  it rescues the exception.

  ## Parameters

    - `token_instances`: A list of token instance maps to be processed.

  ## Returns

    - The result of the upsert operation, which may vary depending on the implementation
      of `upsert_with_rescue/1`.
  """
  @spec batch_fetch_instances([map()]) :: nil | [map()]
  def batch_fetch_instances(token_instances) do
    token_instances
    |> batch_prepare_instances_insert_params()
    |> upsert_with_rescue()
  end

  @doc """
  Prepares a batch of token instance insert parameters.

  This function processes a list of token instances, grouping them by contract address hash,
  and handles special logic for CryptoKitties tokens. It fetches token types for non-CryptoKitties
  tokens, retrieves metadata, and formats the results for database insertion.

  ## Parameters

    - `token_instances`: A list of maps representing token instances. Each item should
      contain at least `:contract_address_hash` and `:token_id`.

  ## Returns

    - A list of insert parameters for each token instance, ready for database insertion.

  ## Special Cases

    - CryptoKitties tokens are identified by a specific contract address hash and are handled
      separately with a fixed API endpoint.

    - Errors during metadata retrieval are truncated and included in the result.

  """
  @spec batch_prepare_instances_insert_params([map()]) :: [map()]
  def batch_prepare_instances_insert_params(token_instances) do
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
        {{:ok, ["https://api.cryptokitties.co/kitties/{id}"]}, to_string(token_id), contract_address_hash, token_id,
         false}
      end)

    other = splitted[false] || []

    token_types_map =
      other
      |> Enum.map(fn {contract_address_hash, _token_id} -> contract_address_hash end)
      |> Enum.uniq()
      |> Chain.get_token_types()
      |> Map.new(fn {hash, type} -> {hash.bytes, type} end)

    other
    |> batch_fetch_instances_inner(token_types_map, cryptokitties)
    |> Enum.map(fn {{_task, res}, {_result, _normalized_token_id, contract_address_hash, token_id, _from_base_uri?}} ->
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
  end

  defp batch_fetch_instances_inner(token_instances, token_types_map, cryptokitties) do
    contract_results =
      (token_instances
       |> Enum.map(fn {contract_address_hash, token_id} ->
         {contract_address_hash, token_id, token_types_map[contract_address_hash.bytes]}
       end)
       |> NFT.batch_metadata_url_request(Application.get_env(:explorer, :json_rpc_named_arguments))
       |> Enum.zip_reduce(token_instances, [], fn {result, from_base_uri?}, {contract_address_hash, token_id}, acc ->
         token_id = NFT.prepare_token_id(token_id)

         [
           {result, normalize_token_id(token_types_map[contract_address_hash.bytes], token_id), contract_address_hash,
            token_id, from_base_uri?}
           | acc
         ]
       end)
       |> Enum.reverse()) ++
        cryptokitties

    contract_results
    |> Enum.map(fn {result, normalized_token_id, _contract_address_hash, token_id, from_base_uri?} ->
      Task.async(fn -> MetadataRetriever.fetch_json(result, token_id, normalized_token_id, from_base_uri?) end)
    end)
    |> Task.yield_many(:infinity)
    |> Enum.zip(contract_results)
  end

  @spec normalize_token_id(binary(), integer()) :: nil | binary()
  defp normalize_token_id("ERC-1155", token_id),
    do: token_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(64, "0")

  defp normalize_token_id(_token_type, _token_id), do: nil

  defp result_to_insert_params({:ok, %{metadata: metadata}}, token_contract_address_hash, token_id) do
    %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      metadata: metadata,
      skip_metadata_url: true,
      error: nil,
      refetch_after: nil
    }
  end

  defp result_to_insert_params({:ok_store_uri, %{metadata: metadata}, uri}, token_contract_address_hash, token_id) do
    %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      metadata: metadata,
      metadata_url: uri,
      skip_metadata_url: false,
      error: nil,
      refetch_after: nil
    }
  end

  defp result_to_insert_params({:error_code, code}, token_contract_address_hash, token_id),
    do: token_instance_map_with_error(token_id, token_contract_address_hash, "request error: #{code}")

  defp result_to_insert_params({:error, reason}, token_contract_address_hash, token_id),
    do: token_instance_map_with_error(token_id, token_contract_address_hash, reason)

  defp token_instance_map_with_error(token_id, token_contract_address_hash, error) do
    config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Retry)

    coef = config[:exp_timeout_coeff]
    max_refetch_interval = config[:max_refetch_interval]

    timeout = min(coef * 1000, max_refetch_interval)

    %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      error: error,
      refetch_after: DateTime.add(DateTime.utc_now(), timeout, :millisecond)
    }
  end

  defp upsert_with_rescue(insert_params, retrying? \\ false) do
    insert_params
    |> Instance.batch_upsert_token_instances()
    |> Queue.process_new_instances()
  rescue
    error in Postgrex.Error ->
      if retrying? do
        Logger.warning(
          [
            "Failed to upsert token instance. Error: #{inspect(error)}, params: #{inspect(insert_params)}"
          ],
          fetcher: :token_instances
        )

        nil
      else
        insert_params
        |> Enum.map(fn params ->
          token_instance_map_with_error(
            params[:token_id],
            params[:token_contract_address_hash],
            MetadataRetriever.truncate_error(inspect(error.postgres.code))
          )
        end)
        |> upsert_with_rescue(true)
      end
  end
end
