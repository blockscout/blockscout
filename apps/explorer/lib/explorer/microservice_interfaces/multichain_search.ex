defmodule Explorer.MicroserviceInterfaces.MultichainSearch do
  @moduledoc """
  Module to interact with Multichain search microservice
  """

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Address, Block, Hash, Transaction}
  alias Explorer.Chain.MultichainSearchDbExportRetryQueue
  alias Explorer.{Helper, Repo}
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response

  require Logger

  @addresses_chunk_size 7_000
  @max_concurrency 5
  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Multichain Search DB Service"
  @unspecified "UNSPECIFIED"

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
  @spec batch_import(
          %{
            addresses: [Address.t()],
            blocks: [Block.t()],
            transactions: [Transaction.t()]
          },
          boolean()
        ) :: {:error, :disabled | String.t() | Jason.DecodeError.t()} | {:ok, any()}
  def batch_import(params, retry? \\ false) do
    if enabled?() do
      params_chunks = extract_batch_import_params_into_chunks(params)

      params_chunks
      |> Task.async_stream(
        fn export_body -> {http_post_request(batch_import_url(), export_body, retry?), export_body} end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout
      )
      |> Enum.reduce_while({:ok, {:chunks_processed, params_chunks}}, fn
        {:ok, {{:ok, _result}, _export_body}}, acc ->
          {:cont, acc}

        {:ok, {{:error, _reason}, export_body}}, _acc ->
          on_error(export_body, retry?)
          {:halt, {:error, @request_error_msg}}

        {:exit, {_, export_body}}, _acc ->
          on_error(export_body, retry?)
          {:halt, {:error, @request_error_msg}}
      end)
    else
      {:ok, :service_disabled}
    end
  end

  @spec on_error(
          %{
            addresses: [Address.t()],
            hashes: [Block.t() | Transaction.t()]
          },
          boolean()
        ) :: {non_neg_integer(), nil | [term()]} | :ok
  defp on_error(%{addresses: addresses, hashes: hashes}, retry?) do
    hashes_to_retry =
      hashes
      |> Enum.map(
        &%{
          hash: Helper.hash_to_binary(&1.hash),
          hash_type: &1.hash_type |> String.downcase() |> String.to_existing_atom()
        }
      )

    addresses_to_retry =
      addresses
      |> Enum.map(fn %{hash: address_hash_string} ->
        %{
          hash: Helper.hash_to_binary(address_hash_string),
          hash_type: :address
        }
      end)

    prepared_data = hashes_to_retry ++ addresses_to_retry

    unless retry?,
      do:
        Repo.insert_all(MultichainSearchDbExportRetryQueue, Helper.add_timestamps(prepared_data), on_conflict: :nothing)
  end

  @spec http_post_request(String.t(), map(), boolean()) :: {:ok, any()} | {:error, String.t()}
  defp http_post_request(url, body, retry?) do
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

        on_error(body, retry?)

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

        on_error(body, retry?)

        {:error, @request_error_msg}
    end
  end

  @spec extract_batch_import_params_into_chunks(%{
          addresses: [Address.t()],
          blocks: [Block.t()],
          transactions: [Transaction.t()]
        }) :: [
          %{
            api_key: String.t(),
            chain_id: String.t(),
            addresses: [String.t()],
            block_ranges: [%{min_block_number: String.t(), max_block_number: String.t()}],
            hashes: [%{hash: String.t(), hash_type: String.t()}]
          }
        ]
  defp extract_batch_import_params_into_chunks(%{
         addresses: raw_addresses,
         blocks: blocks,
         transactions: transactions
       }) do
    chain_id = ChainId.get_id()
    block_ranges = get_block_ranges(blocks)

    addresses =
      raw_addresses
      |> Enum.uniq()
      |> Repo.preload([:token, :smart_contract])
      |> Enum.map(&format_address(&1))

    block_hashes = format_blocks(blocks)

    transaction_hashes = format_transactions(transactions)

    block_transaction_hashes = block_hashes ++ transaction_hashes

    indexed_addresses_chunks =
      addresses
      |> Enum.chunk_every(@addresses_chunk_size)
      |> Enum.with_index()

    api_key = api_key()
    chain_id_string = to_string(chain_id)

    base_data_chunk = %{
      api_key: api_key,
      chain_id: chain_id_string,
      addresses: [],
      block_ranges: block_ranges
    }

    if Enum.empty?(indexed_addresses_chunks) do
      [
        base_data_chunk
        |> Map.put(:hashes, block_transaction_hashes)
      ]
    else
      Enum.map(indexed_addresses_chunks, fn {addresses_chunk, index} ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        hashes = if index == 0, do: block_transaction_hashes, else: []

        base_data_chunk
        |> Map.put(:addresses, addresses_chunk)
        |> Map.put(:hashes, hashes)
      end)
    end
  end

  defp format_address(address) do
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
  end

  @spec format_blocks([Block.t() | %{hash: String.t(), hash_type: String.t()}]) :: [
          %{hash: String.t(), hash_type: String.t()}
        ]
  defp format_blocks(blocks) do
    blocks
    |> Enum.map(&format_block(to_string(&1.hash)))
  end

  @spec format_transactions([Transaction.t() | %{hash: String.t(), hash_type: String.t()}]) :: [
          %{hash: String.t(), hash_type: String.t()}
        ]
  defp format_transactions(transactions) do
    transactions
    |> Enum.map(&format_transaction(to_string(&1.hash)))
  end

  @spec format_block(String.t()) :: %{
          hash: String.t(),
          hash_type: String.t()
        }
  defp format_block(block_hash_string) do
    %{
      hash: block_hash_string,
      hash_type: "BLOCK"
    }
  end

  @spec format_transaction(String.t()) :: %{
          hash: String.t(),
          hash_type: String.t()
        }
  defp format_transaction(transaction_hash_string) do
    %{
      hash: transaction_hash_string,
      hash_type: "TRANSACTION"
    }
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

  defp get_token_type(nil), do: @unspecified

  defp get_token_type(%NotLoaded{}), do: @unspecified

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
