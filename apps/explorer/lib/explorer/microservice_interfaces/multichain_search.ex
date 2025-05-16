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
      url = batch_import_url()

      params_chunks
      |> Task.async_stream(
        fn export_body -> http_post_request(url, export_body, retry?) end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout,
        zip_input_on_exit: true
      )
      |> Enum.reduce({:ok, {:chunks_processed, params_chunks}}, fn
        {:ok, {:ok, _result}}, acc ->
          acc

        {:ok, {:error, error}}, _acc ->
          on_error(error, retry?)
          {:error, @request_error_msg}

        {:exit, {export_body, reason}}, _acc ->
          on_error(
            %{
              url: url,
              data_to_retry: export_body,
              reason: reason
            },
            retry?
          )

          {:error, @request_error_msg}
      end)
    else
      {:ok, :service_disabled}
    end
  end

  defp log_error(%{
         url: url,
         data_to_retry: data_to_retry,
         reason: reason
       }) do
    old_truncate = Application.get_env(:logger, :truncate)
    Logger.configure(truncate: :infinity)

    Logger.error(fn ->
      [
        "Error while sending request to microservice url: #{url}, ",
        "request_body: #{inspect(data_to_retry |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}, ",
        "error_reason: #{inspect(reason, limit: :infinity, printable_limit: :infinity)}"
      ]
    end)

    Logger.configure(truncate: old_truncate)
  end

  defp log_error(%{
         url: url,
         data_to_retry: data_to_retry,
         status_code: status_code,
         response_body: response_body
       }) do
    old_truncate = Application.get_env(:logger, :truncate)
    Logger.configure(truncate: :infinity)

    Logger.error(fn ->
      [
        "Error while sending request to microservice url: #{url}, ",
        "request_body: #{inspect(data_to_retry |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}, ",
        "status_code: #{inspect(status_code)}, ",
        "response_body: #{inspect(response_body, limit: :infinity, printable_limit: :infinity)}"
      ]
    end)

    Logger.configure(truncate: old_truncate)
  end

  @spec on_error(
          map(),
          boolean()
        ) :: {non_neg_integer(), nil | [term()]} | :ok
  # sobelow_skip ["DOS.StringToAtom"]
  defp on_error(
         %{
           data_to_retry: %{addresses: addresses, hashes: hashes}
         } = error,
         false
       ) do
    log_error(error)

    hashes_to_retry =
      hashes
      |> Enum.map(
        &%{
          hash: Helper.hash_to_binary(&1.hash),
          hash_type: &1.hash_type |> String.downcase() |> String.to_atom()
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

    Repo.insert_all(MultichainSearchDbExportRetryQueue, Helper.add_timestamps(prepared_data), on_conflict: :nothing)
  end

  defp on_error(_, _), do: :ignore

  @spec http_post_request(String.t(), map(), boolean()) :: {:ok, any()} | {:error, String.t()}
  defp http_post_request(url, body, retry?) do
    headers = [{"Content-Type", "application/json"}]

    case Application.get_env(:explorer, :http_adapter).post(url, Jason.encode!(body), headers,
           recv_timeout: @post_timeout,
           hackney: [pool: false]
         ) do
      {:ok, %Response{body: response_body, status_code: 200}} ->
        response_body |> Jason.decode()

      {:ok, %Response{body: response_body, status_code: status_code}} ->
        {:error,
         %{
           url: url,
           data_to_retry: body,
           retry?: retry?,
           status_code: status_code,
           response_body: response_body
         }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error,
         %{
           url: url,
           data_to_retry: body,
           retry?: retry?,
           reason: reason
         }}
    end
  end

  @doc """
  Extracts batch import parameters into chunks for processing.

  This function takes a map containing `addresses`, `blocks`, and `transactions`,
  and processes them into chunks suitable for batch import. It performs the following steps:

  - Retrieves the chain ID.
  - Computes block ranges from the given blocks.
  - Preloads associated `:token` and `:smart_contract` data for the addresses, removes duplicates, and formats them.
  - Formats the blocks and transactions into hashes.
  - Combines block hashes and transaction hashes into a single list of `block_transaction_hashes`.
  - Splits the formatted addresses into chunks of size `addresses_chunk_size()` and indexes them.
  - Constructs a base data chunk containing the API key, chain ID, and block ranges.

  The function returns a list of data chunks. If there are no addresses, it returns a single chunk with only the `block_transaction_hashes`. Otherwise, it creates a chunk for each group of addresses, including the `block_transaction_hashes` only in the first chunk.

  ## Parameters

  - `%{addresses: raw_addresses, blocks: blocks, transactions: transactions}`: A map containing:
    - `addresses`: A list of raw address data.
    - `blocks`: A list of block data.
    - `transactions`: A list of transaction data.

  ## Returns

  - A list of maps, where each map represents a chunk of data for batch import. Each chunk contains:
    - `:api_key`: The API key for the request.
    - `:chain_id`: The chain ID as a string.
    - `:addresses`: A chunk of formatted addresses.
    - `:block_ranges`: The computed block ranges.
    - `:hashes`: A list of block and transaction hashes (only included in the first chunk).

  """
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
  def extract_batch_import_params_into_chunks(%{
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
      |> Enum.chunk_every(addresses_chunk_size())
      |> Enum.with_index()

    api_key = api_key()
    chain_id_string = to_string(chain_id)

    base_data_chunk = %{
      api_key: api_key,
      chain_id: chain_id_string,
      addresses: [],
      block_ranges: []
    }

    if Enum.empty?(indexed_addresses_chunks) do
      [
        base_data_chunk
        |> Map.put(:hashes, block_transaction_hashes)
        |> Map.put(:block_ranges, block_ranges)
      ]
    else
      Enum.map(indexed_addresses_chunks, fn {addresses_chunk, index} ->
        # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
        hashes_in_chunk = if index == 0, do: block_transaction_hashes, else: []
        block_ranges_in_chunk = if index == 0, do: block_ranges, else: []

        base_data_chunk
        |> Map.put(:addresses, addresses_chunk)
        |> Map.put(:hashes, hashes_in_chunk)
        |> Map.put(:block_ranges, block_ranges_in_chunk)
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

  defp addresses_chunk_size do
    Application.get_env(:explorer, __MODULE__)[:addresses_chunk_size]
  end
end
