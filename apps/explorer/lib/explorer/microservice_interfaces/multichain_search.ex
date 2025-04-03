defmodule Explorer.MicroserviceInterfaces.MultichainSearch do
  @moduledoc """
  Module to interact with Multichain search microservice
  """

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Address, Block, Hash, Transaction}
  alias Explorer.Repo
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response

  require Logger

  @addresses_chunk_size 7_000
  @max_concurrency 5
  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Multichain Search Service"

  @doc """
    Performs a batch import of addresses, blocks, and transactions to the Multichain Search microservice.

    ## Parameters
    - `params`: A map containing:
      - `addresses`: List of address structs.
      - `blocks`: List of block structs.
      - `transactions`: List of transaction structs.

    ## Returns
    - `{:ok, :service_disabled}`: If the integration with Multichain Search Service is disabled.
    - `{:ok, result}`: If the import was successful.
    - `{:error, reason}`: If an error occurred.
  """
  @spec batch_import(%{
          addresses: [Address.t()],
          blocks: [Block.t()],
          transactions: [Transaction.t()]
        }) :: {:error, :disabled | String.t() | Jason.DecodeError.t()} | {:ok, any()}
  def batch_import(params) do
    if enabled?() do
      params_chunks = extract_batch_import_params_into_chunks(params)

      params_chunks
      |> Task.async_stream(
        fn body -> http_post_request(batch_import_url(), body) end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout
      )
      |> Enum.reduce_while({:ok, :chunks_processed}, fn
        {:ok, _result}, acc -> {:cont, acc}
        {:exit, _reason}, _acc -> {:halt, {:error, @request_error_msg}}
        {:error, _reason}, _acc -> {:halt, {:error, @request_error_msg}}
      end)
    else
      {:ok, :service_disabled}
    end
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: response_body, status_code: 200}} ->
        response_body |> Jason.decode()

      {:ok, %Response{body: response_body, status_code: status_code}} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to microservice url: #{url}, ",
            "status_code: #{inspect(status_code)}, ",
            "response_body: #{inspect(response_body, limit: :infinity, printable_limit: :infinity)}, ",
            "request_body: #{inspect(body |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}"
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}

      error ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to microservice url: #{url}, request_body: #{inspect(body |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  defp extract_batch_import_params_into_chunks(%{
         addresses: raw_addresses,
         blocks: blocks,
         transactions: transactions
       }) do
    chain_id = ChainId.get_id()
    block_ranges = get_block_ranges(blocks)

    addresses =
      raw_addresses
      |> Repo.preload([:token, :smart_contract])
      |> Enum.map(fn address ->
        %{
          hash: Hash.to_string(address.hash),
          is_contract: !is_nil(address.contract_code),
          is_verified_contract: address.verified,
          is_token: token?(address.token),
          ens_name: address.ens_domain_name,
          token_name: get_token_name(address.token),
          token_type: get_token_type(address.token),
          contract_name: get_smart_contract_name(address.smart_contract)
        }
      end)
      |> Enum.uniq()

    block_hashes =
      blocks
      |> Enum.map(
        &%{
          hash: Hash.to_string(&1.hash),
          hash_type: "BLOCK"
        }
      )

    transaction_hashes =
      transactions
      |> Enum.map(
        &%{
          hash: Hash.to_string(&1.hash),
          hash_type: "TRANSACTION"
        }
      )

    block_transaction_hashes = block_hashes ++ transaction_hashes

    indexed_addresses_chunks =
      addresses
      |> Enum.chunk_every(@addresses_chunk_size)
      |> Enum.with_index()

    Enum.map(indexed_addresses_chunks, fn {addresses_chunk, index} ->
      hashes = if index == 0, do: block_transaction_hashes, else: []

      %{
        api_key: api_key(),
        chain_id: to_string(chain_id),
        addresses: addresses_chunk,
        block_ranges: block_ranges,
        hashes: hashes
      }
    end)
  end

  defp token?(nil), do: false

  defp token?(%NotLoaded{}), do: false

  defp token?(_), do: true

  defp get_token_name(nil), do: nil

  defp get_token_name(%NotLoaded{}), do: nil

  defp get_token_name(token), do: token.name

  defp get_smart_contract_name(nil), do: nil

  defp get_smart_contract_name(%NotLoaded{}), do: nil

  defp get_smart_contract_name(smart_contract), do: smart_contract.name

  defp get_token_type(nil), do: "UNSPECIFIED"

  defp get_token_type(%NotLoaded{}), do: "UNSPECIFIED"

  defp get_token_type(token), do: token.type

  defp get_block_ranges([]), do: []

  defp get_block_ranges(blocks) do
    {min_block_number, max_block_number} =
      blocks
      |> Enum.map(& &1.number)
      |> Enum.min_max()

    [
      %{
        min_block_number: to_string(min_block_number),
        max_block_number: to_string(max_block_number)
      }
    ]
  end

  defp batch_import_url do
    "#{base_url()}/import:batch"
  end

  defp base_url do
    microservice_base_url = Microservice.base_url(__MODULE__)

    if microservice_base_url do
      "#{microservice_base_url}/api/v1"
    else
      nil
    end
  end

  defp api_key do
    Microservice.api_key(__MODULE__)
  end

  @doc """
  Checks if the multichain search microservice is enabled.

  This function determines if the multichain search microservice is enabled by
  checking if the base URL is not nil.

  ## Examples

    iex> Explorer.MicroserviceInterfaces.MultichainSearch.enabled?()
    true

    iex> Explorer.MicroserviceInterfaces.MultichainSearch.enabled?()
    false

  @return `true` if the base URL is not nil, `false` otherwise.
  """
  def enabled?, do: !is_nil(base_url())
end
