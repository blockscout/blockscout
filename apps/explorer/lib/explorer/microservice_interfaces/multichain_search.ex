defmodule Explorer.MicroserviceInterfaces.MultichainSearch do
  @moduledoc """
  Module to interact with Multichain search microservice
  """
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.{Block, Hash, Transaction, Wei}
  alias Explorer.Chain.Block.Range
  alias Explorer.Chain.MultichainSearchDb.{BalancesExportQueue, MainExportQueue}
  alias Explorer.{Helper, Repo}
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response

  require Decimal
  require Logger

  @max_concurrency 5
  @post_timeout :timer.minutes(5)
  @unspecified "UNSPECIFIED"

  @doc """
  Processes a batch import of data by splitting the input parameters into chunks and sending each chunk as an HTTP POST request to a configured microservice endpoint.

  If the microservice is enabled, the function:
    - Splits the input `params` into manageable chunks.
    - Sends each chunk concurrently using `Task.async_stream/3` with a maximum concurrency and timeout.
    - Collects the results, merging any errors and accumulating data that needs to be retried.
    - Returns `{:ok, {:chunks_processed, params_chunks}}` if all chunks are processed successfully.
    - Returns `{:error, data_to_retry}` if any chunk fails, where `data_to_retry` contains the addresses, block ranges, and hashes that need to be retried.

  If the microservice is disabled, returns `{:ok, :service_disabled}`.

  ## Parameters

    - `params` (`map()`): The parameters to be imported, which will be split into chunks for processing.

  ## Returns

    - `{:ok, any()}`: If all chunks are processed successfully or the service is disabled.
    - `{:error, map()}`: If one or more chunks fail, with details about the data that needs to be retried.
  """
  @spec batch_import(map()) :: {:error, map()} | {:ok, any()}
  def batch_import(params) do
    if enabled?() do
      params_chunks = extract_batch_import_params_into_chunks(params)
      url = batch_import_url()

      params_chunks
      |> Task.async_stream(
        fn export_body -> http_post_request(url, export_body) end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout,
        zip_input_on_exit: true
      )
      |> Enum.reduce({:ok, {:chunks_processed, params_chunks}}, fn
        {:ok, {:ok, _result}}, acc ->
          acc

        {:ok, {:error, error}}, acc ->
          on_error(error)

          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error,
               %{
                 addresses: error.data_to_retry.addresses,
                 block_ranges: error.data_to_retry.block_ranges,
                 hashes: error.data_to_retry.hashes
               }}

            {:error, data_to_retry} ->
              merged_data_to_retry = %{
                addresses: error.data_to_retry.addresses ++ data_to_retry.addresses,
                block_ranges: error.data_to_retry.block_ranges ++ data_to_retry.block_ranges,
                hashes: error.data_to_retry.hashes ++ data_to_retry.hashes
              }

              {:error, merged_data_to_retry}
          end

        {:exit, {export_body, reason}}, acc ->
          on_error(%{
            url: url,
            data_to_retry: export_body,
            reason: reason
          })

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error, export_body}

            {:error, acc} ->
              {:error, Map.merge(acc, export_body)}
          end
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
        "error_reason: #{inspect(reason, limit: :infinity, printable_limit: :infinity)}, ",
        "request_body: #{inspect(data_to_retry |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}"
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
        "status_code: #{inspect(status_code)}, ",
        "response_body: #{inspect(response_body, limit: :infinity, printable_limit: :infinity)}, ",
        "request_body: #{inspect(data_to_retry |> Map.drop([:api_key]), limit: :infinity, printable_limit: :infinity)}"
      ]
    end)

    Logger.configure(truncate: old_truncate)
  end

  @spec on_error(map()) :: {non_neg_integer(), nil | [term()]} | :ok
  defp on_error(
         %{
           data_to_retry: data_to_retry
         } = error
       ) do
    log_error(error)

    {prepared_main_data, prepared_balances_data} = prepare_export_data_for_queue(data_to_retry)

    Repo.insert_all(
      MainExportQueue,
      Helper.add_timestamps(prepared_main_data),
      on_conflict: MainExportQueue.default_on_conflict(),
      conflict_target: [:hash, :hash_type]
    )

    Repo.insert_all(
      BalancesExportQueue,
      Helper.add_timestamps(prepared_balances_data),
      on_conflict: BalancesExportQueue.default_on_conflict(),
      conflict_target:
        {:unsafe_fragment, ~s<(address_hash, token_contract_address_hash_or_native, COALESCE(token_id, -1))>}
    )
  end

  defp on_error(_), do: :ignore

  @doc """
  Sends provided blockchain data to the appropriate export queues for further processing.

  Accepts a map containing lists of addresses, blocks, transactions, and address current token balances.
  If all lists are empty, returns `:ignore`. Otherwise, if the export functionality is enabled,
  the data is split into chunks, prepared, and inserted into the `MainExportQueue` and `BalancesExportQueue` tables.
  If the export functionality is disabled, returns `:ignore`.

  ## Parameters

    - `data`: A map with the following keys:
      - `:addresses` - List of address data.
      - `:blocks` - List of block data.
      - `:transactions` - List of transaction data.
      - `:address_current_token_balances` - List of address token balance data.

  ## Returns

    - `:ok` if the data was successfully sent to the queues.
    - `:ignore` if the data is empty or the export functionality is disabled.
  """
  @spec send_data_to_queue(%{
          addresses: list(),
          blocks: list(),
          transactions: list(),
          address_current_token_balances: list()
        }) :: :ignore | :ok
  def send_data_to_queue(%{addresses: [], blocks: [], transactions: [], address_current_token_balances: []}),
    do: :ignore

  def send_data_to_queue(data) do
    if enabled?() do
      data
      |> extract_batch_import_params_into_chunks()
      |> Enum.each(fn data_chunk ->
        {prepared_main_data, prepared_balances_data} = prepare_export_data_for_queue(data_chunk)

        Repo.insert_all(MainExportQueue, Helper.add_timestamps(prepared_main_data), on_conflict: :nothing)

        Repo.insert_all(BalancesExportQueue, Helper.add_timestamps(prepared_balances_data), on_conflict: :nothing)
      end)

      :ok
    else
      :ignore
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp prepare_export_data_for_queue(%{
         addresses: addresses,
         hashes: hashes,
         block_ranges: block_ranges,
         address_coin_balances: address_coin_balances,
         address_token_balances: address_token_balances
       }) do
    block_range =
      case block_ranges do
        [%{min_block_number: nil, max_block_number: nil} | _] ->
          nil

        [%{min_block_number: min_str, max_block_number: max_str} | _] ->
          with {min_num, ""} <- Integer.parse(min_str),
               {max_num, ""} <- Integer.parse(max_str) do
            %Range{from: min_num, to: max_num}
          else
            _ -> nil
          end

        _ ->
          nil
      end

    hashes_to_queue =
      hashes
      |> Enum.map(
        &%{
          hash: Helper.hash_to_binary(&1.hash),
          hash_type: &1.hash_type |> String.downcase() |> String.to_atom(),
          block_range: block_range
        }
      )

    addresses_to_queue =
      addresses
      |> Enum.map(fn %{hash: address_hash_string} ->
        %{
          hash: Helper.hash_to_binary(address_hash_string),
          hash_type: :address,
          block_range: block_range
        }
      end)

    main_queue = hashes_to_queue ++ addresses_to_queue

    coin_balances_queue =
      address_coin_balances
      |> Enum.map(fn %{address_hash: address_hash, value: value} ->
        %{
          address_hash: Helper.hash_to_binary(address_hash),
          token_contract_address_hash_or_native: "native",
          value: value
        }
      end)

    token_balances_queue =
      address_token_balances
      |> Enum.map(fn %{
                       address_hash: address_hash,
                       token_address_hash: token_address_hash,
                       value: value,
                       token_id: token_id
                     } ->
        %{
          address_hash: Helper.hash_to_binary(address_hash),
          token_contract_address_hash_or_native: Helper.hash_to_binary(token_address_hash),
          # value is of Wei type in Explorer.Chain.Address.CoinBalance
          # value is of Decimal type in Explorer.Chain.Address.TokenBalance
          value: if(Decimal.is_decimal(value), do: value |> Wei.cast() |> elem(1), else: value),
          token_id: token_id
        }
      end)

    balances_queue = coin_balances_queue ++ token_balances_queue

    {main_queue, balances_queue}
  end

  @spec http_post_request(String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  defp http_post_request(url, body) do
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
           status_code: status_code,
           response_body: response_body
         }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error,
         %{
           url: url,
           data_to_retry: body,
           reason: reason
         }}
    end
  end

  @doc """
  Extracts and organizes batch import parameters into appropriately sized chunks for processing.

  Given a map of parameters, this function:
  - Extracts block ranges, addresses, block hashes, transaction hashes, address token balances, and address coin balances.
  - Preloads necessary associations for addresses.
  - Formats and deduplicates addresses and balances.
  - Chunks addresses and balances according to a configured chunk size.
  - Assembles a list of maps, each representing a chunk of data to be processed, including API key and chain ID.
  - Ensures that block and transaction hashes, block ranges, and address token balances are only included in the first chunk if addresses are present; otherwise, they are included in a single chunk.

  ## Parameters

    - `params` (`map()`): A map containing batch import parameters. Expected keys include:
      - `:addresses` - List of address structs to process.
      - `:blocks` - List of block data.
      - `:block_ranges` (optional) - Precomputed block ranges.
      - `:block_hashes` (optional) - List of block hashes.
      - `:transactions` - List of transaction data.
      - `:address_current_token_balances` (optional) - List of token balances for addresses.

  ## Returns

    - `list(map())`: A list of maps, each containing a chunk of batch import parameters with the following keys:
      - `:api_key` - The API key as a string.
      - `:chain_id` - The chain ID as a string.
      - `:addresses` - List of address strings for this chunk.
      - `:block_ranges` - List of block range maps for this chunk.
      - `:hashes` - List of hashes (block and transaction) for this chunk.
      - `:address_token_balances` - List of token balance maps for this chunk.
      - `:address_coin_balances` - List of coin balance maps for this chunk.

  If no addresses are present, a single chunk is returned with the relevant hashes, block ranges, and token balances.
  """
  @spec extract_batch_import_params_into_chunks(map()) :: [
          %{
            api_key: String.t(),
            chain_id: String.t(),
            addresses: [String.t()],
            block_ranges: [%{min_block_number: String.t(), max_block_number: String.t()}],
            hashes: [%{hash: String.t(), hash_type: String.t()}],
            address_token_balances: [map()],
            address_coin_balances: [map()]
          }
        ]
  def extract_batch_import_params_into_chunks(params) do
    block_ranges =
      if Map.has_key?(params, :block_ranges),
        do: params.block_ranges,
        else: get_block_ranges(Map.get(params, :blocks, []))

    {addresses, address_coin_balances} =
      params
      |> Map.get(:addresses, [])
      |> Repo.preload([:token, :smart_contract])
      |> Enum.reduce({[], []}, fn address, {acc_addresses, acc_coin_balances} ->
        {[format_address(address) | acc_addresses], [format_address_coin_balance(address) | acc_coin_balances]}
      end)

    block_hashes =
      if Map.has_key?(params, :block_hashes),
        do: format_block_hashes(params.block_hashes),
        else: format_blocks(Map.get(params, :blocks, []))

    transaction_hashes = format_transactions(Map.get(params, :transactions, []))

    block_transaction_hashes = block_hashes ++ transaction_hashes

    indexed_addresses_chunks =
      addresses
      |> Enum.uniq()
      |> Enum.chunk_every(addresses_chunk_size())
      |> Enum.with_index()

    indexed_address_coin_balances_chunks =
      address_coin_balances
      |> Enum.uniq()
      |> Enum.reject(&is_nil(&1.value))
      |> Enum.chunk_every(addresses_chunk_size())

    address_token_balances =
      if Map.has_key?(params, :address_current_token_balances) do
        params.address_current_token_balances
        |> Enum.map(&format_address_token_balance/1)
      else
        []
      end

    api_key = api_key()
    chain_id = ChainId.get_id()
    chain_id_string = to_string(chain_id)

    base_data_chunk = %{
      api_key: api_key,
      chain_id: chain_id_string,
      addresses: [],
      block_ranges: [],
      address_token_balances: [],
      address_coin_balances: []
    }

    if Enum.empty?(indexed_addresses_chunks) do
      [
        base_data_chunk
        |> Map.put(:hashes, block_transaction_hashes)
        |> Map.put(:block_ranges, block_ranges)
        |> Map.put(:address_token_balances, address_token_balances)
      ]
    else
      Enum.map(indexed_addresses_chunks, fn {addresses_chunk, index} ->
        # credo:disable-for-lines:3 Credo.Check.Refactor.Nesting
        hashes_in_chunk = if index == 0, do: block_transaction_hashes, else: []
        block_ranges_in_chunk = if index == 0, do: block_ranges, else: []
        address_token_balances_in_chunk = if index == 0, do: address_token_balances, else: []

        base_data_chunk
        |> Map.put(:addresses, addresses_chunk)
        |> Map.put(:address_coin_balances, indexed_address_coin_balances_chunks |> Enum.at(index) || [])
        |> Map.put(:hashes, hashes_in_chunk)
        |> Map.put(:block_ranges, block_ranges_in_chunk)
        |> Map.put(:address_token_balances, address_token_balances_in_chunk)
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

  defp format_address_coin_balance(address) do
    %{
      address_hash: Hash.to_string(address.hash),
      value: address.fetched_coin_balance
    }
  end

  defp format_address_token_balance(address_current_token_balance) do
    %{
      address_hash: Hash.to_string(address_current_token_balance.address_hash),
      token_address_hash: Hash.to_string(address_current_token_balance.token_contract_address_hash),
      token_id: address_current_token_balance.token_id,
      value: address_current_token_balance.value
    }
  end

  @spec format_blocks([Block.t() | %{hash: String.t(), hash_type: String.t()}]) :: [
          %{hash: String.t(), hash_type: String.t()}
        ]
  defp format_blocks(blocks) do
    blocks
    |> Enum.map(&format_block_hash(to_string(&1.hash)))
  end

  @spec format_block_hashes([Hash.t()]) :: [
          %{hash: String.t(), hash_type: String.t()}
        ]
  defp format_block_hashes(block_hashes) do
    block_hashes
    |> Enum.map(&format_block_hash(to_string(&1)))
  end

  @spec format_transactions([Transaction.t() | %{hash: String.t(), hash_type: String.t()}]) :: [
          %{hash: String.t(), hash_type: String.t()}
        ]
  defp format_transactions(transactions) do
    transactions
    |> Enum.map(&format_transaction(to_string(&1.hash)))
  end

  @spec format_block_hash(String.t()) :: %{
          hash: String.t(),
          hash_type: String.t()
        }
  defp format_block_hash(block_hash_string) do
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

  @doc """
    Returns a full URL to the Multichain service API import endpoint.

    ## Returns
    - A string containing the URL.
  """
  @spec batch_import_url() :: String.t()
  def batch_import_url do
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

  @doc """
    Returns an API key for the Multichain service.

    ## Returns
    - A string containing the API key.
    - `nil` if the key is not defined.
  """
  @spec api_key() :: String.t() | nil
  def api_key do
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
