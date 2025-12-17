defmodule Explorer.MicroserviceInterfaces.MultichainSearch do
  @moduledoc """
  Module to interact with Multichain search microservice
  """
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Hash, Token, Transaction, Wei}
  alias Explorer.Chain.Block.Range
  alias Explorer.Chain.Cache.ChainId

  alias Explorer.Chain.MultichainSearchDb.{
    BalancesExportQueue,
    CountersExportQueue,
    MainExportQueue,
    TokenInfoExportQueue
  }

  alias Explorer.{Helper, HttpClient, Repo}
  alias Explorer.Utility.Microservice

  require Decimal
  require Logger

  @max_concurrency 5
  @post_timeout :timer.minutes(5)

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
    # todo: rename this function to `batch_export` (and all related places in code & comments)
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
                 hashes: error.data_to_retry.hashes,
                 address_coin_balances: error.data_to_retry.address_coin_balances,
                 address_token_balances: error.data_to_retry.address_token_balances
               }}

            {:error, data_to_retry} ->
              merged_data_to_retry = %{
                addresses: error.data_to_retry.addresses ++ data_to_retry.addresses,
                block_ranges: error.data_to_retry.block_ranges ++ data_to_retry.block_ranges,
                hashes: error.data_to_retry.hashes ++ data_to_retry.hashes,
                address_coin_balances: error.data_to_retry.address_coin_balances ++ data_to_retry.address_coin_balances,
                address_token_balances:
                  error.data_to_retry.address_token_balances ++ data_to_retry.address_token_balances
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

            {:error, error} ->
              merged_data_to_retry = %{
                addresses: error.data_to_retry.addresses ++ export_body.addresses,
                block_ranges: error.data_to_retry.block_ranges ++ export_body.block_ranges,
                hashes: error.data_to_retry.hashes ++ export_body.hashes,
                address_coin_balances: error.data_to_retry.address_coin_balances ++ export_body.address_coin_balances,
                address_token_balances: error.data_to_retry.address_token_balances ++ export_body.address_token_balances
              }

              {:error, merged_data_to_retry}
          end
      end)
    else
      {:ok, :service_disabled}
    end
  end

  @doc """
    Processes a batch export of token info by splitting the items from db queue into chunks and sending each chunk as an HTTP POST request to a configured microservice endpoint.

    If the microservice is enabled, the function:
    - Splits the input `items_from_db_queue` into manageable chunks.
    - Sends each chunk concurrently using `Task.async_stream/5` with a maximum concurrency and timeout.
    - Collects the results, merging any errors and accumulating data that needs to be retried.
    - Returns `{:ok, {:chunks_processed, chunks}}` if all chunks are processed successfully.
    - Returns `{:error, data_to_retry}` if any chunk fails, where `data_to_retry` contains tokens that need to be retried.

    If the microservice is disabled, returns `{:ok, :service_disabled}`.

    ## Parameters
    - `items_from_db_queue`: The queue items to be exported, which will be split into chunks for processing.

    ## Returns
    - `{:ok, any()}`: If all chunks are processed successfully or the service is disabled.
    - `{:error, map()}`: If one or more chunks fail, with details about the data that needs to be retried.
  """
  @spec batch_export_token_info([
          %{
            :address_hash => binary(),
            :data_type => :metadata | :total_supply | :counters | :market_data,
            :data => map()
          }
        ]) :: {:ok, any()} | {:error, map()}
  def batch_export_token_info(items_from_db_queue) do
    if enabled?() do
      url = batch_import_url()
      api_key = api_key()
      chain_id = to_string(ChainId.get_id())

      chunks =
        items_from_db_queue
        |> Enum.chunk_every(token_info_chunk_size())
        |> Enum.map(fn chunk_items ->
          %{
            api_key: api_key,
            chain_id: chain_id,
            tokens: Enum.map(chunk_items, &token_info_queue_item_to_http_item(&1))
          }
        end)

      chunks
      |> Task.async_stream(
        fn export_body -> http_post_request(url, export_body) end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout,
        zip_input_on_exit: true
      )
      |> Enum.reduce({:ok, {:chunks_processed, chunks}}, fn
        {:ok, {:ok, _result}}, acc ->
          acc

        {:ok, {:error, error}}, acc ->
          token_info_on_error(error)

          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error, %{tokens: error.data_to_retry.tokens}}

            {:error, data_to_retry} ->
              {:error, %{tokens: data_to_retry.tokens ++ error.data_to_retry.tokens}}
          end

        {:exit, {export_body, reason}}, acc ->
          token_info_on_error(%{
            url: url,
            data_to_retry: export_body,
            reason: reason
          })

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error, %{tokens: export_body.tokens}}

            {:error, data_to_retry} ->
              {:error, %{tokens: data_to_retry.tokens ++ export_body.tokens}}
          end
      end)
    else
      {:ok, :service_disabled}
    end
  end

  @doc """
    Processes a batch export of counters by splitting the items from db queue into chunks
    and sending each chunk as an HTTP POST request to a configured microservice endpoint.

    If the microservice is enabled, the function:
    - Splits the input `items_from_db_queue` into manageable chunks.
    - Sends each chunk concurrently using `Task.async_stream/5` with a maximum concurrency and timeout.
    - Collects the results, merging any errors and accumulating data that needs to be retried.
    - Returns `{:ok, {:chunks_processed, chunks}}` if all chunks are processed successfully.
    - Returns `{:error, data_to_retry}` if any chunk fails, where `data_to_retry` contains counters that need to be retried.

    If the microservice is disabled, returns `{:ok, :service_disabled}`.

    ## Parameters
    - `items_from_db_queue`: The queue items to be exported, which will be split into chunks for processing.

    ## Returns
    - `{:ok, any()}`: If all chunks are processed successfully or the service is disabled.
    - `{:error, map()}`: If one or more chunks fail, with details about the data that needs to be retried.
  """
  @spec batch_export_counters([
          %{
            :timestamp => DateTime.t(),
            :counter_type => :global,
            :data => map()
          }
        ]) :: {:ok, any()} | {:error, map()}
  def batch_export_counters(items_from_db_queue) do
    if enabled?() do
      url = batch_import_url()
      api_key = api_key()
      chain_id = to_string(ChainId.get_id())

      chunks =
        items_from_db_queue
        |> Enum.chunk_every(counters_chunk_size())
        |> Enum.map(fn chunk_items ->
          %{
            api_key: api_key,
            chain_id: chain_id,
            counters: Enum.map(chunk_items, &counter_queue_item_to_http_item(&1))
          }
        end)

      chunks
      |> Task.async_stream(
        fn export_body -> http_post_request(url, export_body) end,
        max_concurrency: @max_concurrency,
        timeout: @post_timeout,
        zip_input_on_exit: true
      )
      |> Enum.reduce({:ok, {:chunks_processed, chunks}}, fn
        {:ok, {:ok, _result}}, acc ->
          acc

        {:ok, {:error, error}}, acc ->
          counter_on_error(error)

          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error, %{counters: error.data_to_retry.counters}}

            {:error, data_to_retry} ->
              {:error, %{counters: data_to_retry.counters ++ error.data_to_retry.counters}}
          end

        {:exit, {export_body, reason}}, acc ->
          counter_on_error(%{
            url: url,
            data_to_retry: export_body,
            reason: reason
          })

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case acc do
            {:ok, {:chunks_processed, _}} ->
              {:error, %{counters: export_body.counters}}

            {:error, data_to_retry} ->
              {:error, %{counters: data_to_retry.counters ++ export_body.counters}}
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

  # Logs error when trying to send token info from the queue to Multichain service
  # and increments `retries_number` counter of the corresponding queue items.
  #
  # ## Parameters
  # - `error`: A map with the queue items.
  #
  # ## Returns
  # - Nothing.
  @spec token_info_on_error(%{
          :data_to_retry => %{:tokens => [map()], optional(any()) => any()},
          optional(any()) => any()
        }) :: any()
  defp token_info_on_error(%{data_to_retry: data_to_retry} = error) do
    log_error(error)

    prepared_token_info_data =
      data_to_retry.tokens
      |> Enum.map(&token_info_http_item_to_queue_item(&1))
      |> Helper.add_timestamps()

    Repo.insert_all(
      TokenInfoExportQueue,
      prepared_token_info_data,
      on_conflict: TokenInfoExportQueue.increase_retries_on_conflict(),
      conflict_target: [:address_hash, :data_type]
    )
  end

  defp token_info_on_error(_), do: :ignore

  # Logs error when trying to send counter from the queue to Multichain service
  # and increments `retries_number` counter of the corresponding queue items.
  #
  # ## Parameters
  # - `error`: A map with the queue items.
  #
  # ## Returns
  # - Nothing.
  @spec counter_on_error(%{
          :data_to_retry => %{:counters => [map()], optional(any()) => any()},
          optional(any()) => any()
        }) :: any()
  defp counter_on_error(%{data_to_retry: data_to_retry} = error) do
    log_error(error)

    prepared_counters_data =
      data_to_retry.counters
      |> Enum.map(&counter_http_item_to_queue_item(&1))
      |> Helper.add_timestamps()

    Repo.insert_all(
      CountersExportQueue,
      prepared_counters_data,
      on_conflict: CountersExportQueue.increase_retries_on_conflict(),
      conflict_target: [:timestamp, :counter_type]
    )
  end

  defp counter_on_error(_), do: :ignore

  @doc """
    Converts database queue item with token info to the item ready to send to Multichain service via HTTP.

    ## Parameters
    - `item_from_db_queue`: The queue item map from database.

    ## Returns
    - A map ready to send to Multichain service via HTTP.
  """
  @spec token_info_queue_item_to_http_item(%{
          :address_hash => binary(),
          :data_type => :metadata | :total_supply | :counters | :market_data,
          :data => map()
        }) ::
          %{:address_hash => String.t(), :metadata => map()}
          | %{:address_hash => String.t(), :counters => map()}
          | %{:address_hash => String.t(), :price_data => map()}
  def token_info_queue_item_to_http_item(item_from_db_queue) do
    token = %{address_hash: "0x" <> Base.encode16(item_from_db_queue.address_hash, case: :lower)}

    case item_from_db_queue.data_type do
      :metadata -> Map.put(token, :metadata, item_from_db_queue.data)
      :total_supply -> Map.put(token, :metadata, item_from_db_queue.data)
      :counters -> Map.put(token, :counters, item_from_db_queue.data)
      :market_data -> Map.put(token, :price_data, item_from_db_queue.data)
    end
  end

  @doc """
    Converts queue item (containing token info) ready to send to Multichain service via HTTP
    to the queue item ready to be written to the database.

    ## Parameters
    - `http_item`: The queue item for HTTP.

    ## Returns
    - A map ready to write to the database.
  """
  @spec token_info_http_item_to_queue_item(
          %{:address_hash => String.t(), :metadata => map()}
          | %{:address_hash => String.t(), :counters => map()}
          | %{:address_hash => String.t(), :price_data => map()}
        ) :: %{
          :address_hash => binary(),
          :data_type => :metadata | :total_supply | :counters | :market_data,
          :data => map()
        }
  def token_info_http_item_to_queue_item(%{address_hash: "0x" <> address_string} = http_item) do
    {:ok, address_hash} = Base.decode16(address_string, case: :mixed)

    metadata = Map.get(http_item, :metadata)

    {data_type, data} =
      cond do
        !is_nil(metadata) and (!is_nil(Map.get(metadata, :token_type)) or !is_nil(Map.get(metadata, "token_type"))) ->
          {:metadata, http_item[:metadata]}

        !is_nil(metadata) ->
          {:total_supply, http_item[:metadata]}

        !is_nil(Map.get(http_item, :counters)) ->
          {:counters, http_item[:counters]}

        !is_nil(Map.get(http_item, :price_data)) ->
          {:market_data, http_item[:price_data]}
      end

    %{
      address_hash: address_hash,
      data_type: data_type,
      data: data
    }
  end

  @doc """
    Converts database queue item with counters to the item ready to send to Multichain service via HTTP.

    ## Parameters
    - `item_from_db_queue`: The queue item map from database.

    ## Returns
    - A map ready to send to Multichain service via HTTP.
  """
  @spec counter_queue_item_to_http_item(%{
          :timestamp => DateTime.t(),
          :counter_type => :global,
          :data => map()
        }) :: %{:timestamp => String.t(), :global_counters => map()}
  def counter_queue_item_to_http_item(item_from_db_queue) do
    counter = %{timestamp: to_string(DateTime.to_unix(item_from_db_queue.timestamp))}

    case item_from_db_queue.counter_type do
      :global -> Map.put(counter, :global_counters, item_from_db_queue.data)
    end
  end

  @doc """
    Converts queue item (containing counter data) ready to send to Multichain service via HTTP
    to the queue item ready to be written to the database.

    ## Parameters
    - `http_item`: The queue item for HTTP.

    ## Returns
    - A map ready to write to the database.
  """
  @spec counter_http_item_to_queue_item(%{:timestamp => String.t(), :global_counters => map()}) :: %{
          :timestamp => DateTime.t(),
          :counter_type => :global,
          :data => map()
        }
  def counter_http_item_to_queue_item(%{timestamp: timestamp_string} = http_item) do
    timestamp_integer = String.to_integer(timestamp_string)

    %{
      timestamp: DateTime.from_unix!(timestamp_integer * 1_000_000, :microsecond),
      counter_type: :global,
      data: http_item[:global_counters]
    }
  end

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
  @spec send_data_to_queue(map()) :: :ignore | :ok
  def send_data_to_queue(%{addresses: [], blocks: [], transactions: [], address_current_token_balances: []}),
    do: :ignore

  def send_data_to_queue(data) do
    if enabled?() do
      data
      |> extract_batch_import_params_into_chunks()
      |> Enum.each(fn data_chunk ->
        {prepared_main_data, prepared_balances_data} = prepare_export_data_for_queue(data_chunk)

        Repo.insert_all(MainExportQueue, Helper.add_timestamps(prepared_main_data), on_conflict: :nothing)

        Repo.insert_all(BalancesExportQueue, Helper.add_timestamps(prepared_balances_data),
          on_conflict: {:replace, [:value, :updated_at]},
          conflict_target:
            {:unsafe_fragment,
             ~s<(address_hash, token_contract_address_hash_or_native, COALESCE(token_id, -1::integer::numeric))>}
        )
      end)

      :ok
    else
      :ignore
    end
  end

  @doc """
    Prepares token metadata for writing to database queue and subsequent sending to Multichain service.

    ## Parameters
    - `token`: An instance of `Token.t()` containing token type and probably `icon_url`.
    - `metadata`: A map with token metadata.

    ## Returns
    - A map containing token type and its metadata in the format approved on Multichain service.
  """
  @spec prepare_token_metadata_for_queue(Token.t(), %{
          :token_type => String.t(),
          optional(:name) => String.t(),
          optional(:symbol) => String.t(),
          optional(:decimals) => non_neg_integer(),
          optional(:total_supply) => non_neg_integer(),
          optional(any()) => any()
        }) :: %{
          optional(:token_type) => String.t(),
          optional(:name) => String.t(),
          optional(:symbol) => String.t(),
          optional(:decimals) => String.t(),
          optional(:total_supply) => String.t(),
          optional(:icon_url) => String.t()
        }
  def prepare_token_metadata_for_queue(%Token{} = token, metadata) do
    if enabled?() do
      %{token_type: token.type}
      |> token_optional_field(metadata, :name)
      |> token_optional_field(metadata, :symbol)
      |> token_optional_field(token, :icon_url)
      |> token_optional_field(metadata, :decimals)
      |> token_optional_field(metadata, :total_supply, true)
    else
      %{}
    end
  end

  @doc """
    Prepares token total supply for writing to database queue and subsequent sending to Multichain service.

    ## Parameters
    - `total_supply`: The total supply value. Can be `nil`.

    ## Returns
    - A map containing total supply in the format approved on Multichain service.
    - `nil` if the `total_supply` parameter is `nil`.
  """
  @spec prepare_token_total_supply_for_queue(non_neg_integer() | nil) :: %{:total_supply => String.t()} | nil
  def prepare_token_total_supply_for_queue(nil), do: nil

  def prepare_token_total_supply_for_queue(total_supply) do
    if enabled?() do
      %{total_supply: to_string(total_supply)}
    end
  end

  @doc """
    Prepares token market data (such as price and market cap) for writing to database queue
    and subsequent sending to Multichain service.

    ## Parameters
    - `token`: A token map containing the market data.

    ## Returns
    - A map containing the market data in the format approved on Multichain service.
  """
  @spec prepare_token_market_data_for_queue(%{
          optional(:fiat_value) => Decimal.t(),
          optional(:circulating_market_cap) => Decimal.t(),
          optional(any()) => any()
        }) :: map()
  def prepare_token_market_data_for_queue(token) do
    if enabled?() do
      %{}
      |> token_optional_field(token, :fiat_value)
      |> token_optional_field(token, :circulating_market_cap)
      |> Enum.map(fn {key, value} ->
        {key, Decimal.to_string(value, :normal)}
      end)
      |> Enum.into(%{})
    else
      %{}
    end
  end

  @doc """
    Prepares token counters for writing to database queue and subsequent sending to Multichain service.

    ## Parameters
    - `transfer_count`: The number of the token transfers count.
    - `holder_count`: The number of the token holders count.

    ## Returns
    - A map containing the counters in the format approved on Multichain service.
  """
  @spec prepare_token_counters_for_queue(non_neg_integer(), non_neg_integer()) :: %{
          :transfers_count => String.t(),
          :holders_count => String.t()
        }
  def prepare_token_counters_for_queue(transfers_count, holders_count) do
    if enabled?() do
      %{transfers_count: to_string(transfers_count), holders_count: to_string(holders_count)}
    else
      %{}
    end
  end

  @spec filter_addresses_to_multichain_import(
          [Address.t()],
          atom() | nil
        ) :: [Address.t()]
  def filter_addresses_to_multichain_import(addresses, :on_demand) do
    addresses
    |> Enum.filter(fn %Address{
                        fetched_coin_balance: fetched_coin_balance,
                        transactions_count: transactions_count,
                        token_transfers_count: token_transfers_count
                      } ->
      case fetched_coin_balance do
        %Wei{value: value} -> Decimal.compare(value, 0) == :gt
        _ -> false
      end ||
        (is_number(transactions_count) and transactions_count > 0) ||
        (is_number(token_transfers_count) and token_transfers_count > 0)
    end)
  end

  def filter_addresses_to_multichain_import(addresses, _broadcast) do
    addresses
  end

  defp token_optional_field(data, metadata, key, convert_to_string \\ false) do
    case Map.get(metadata, key) do
      nil ->
        data

      value ->
        if convert_to_string do
          Map.put(data, key, to_string(value))
        else
          Map.put(data, key, value)
        end
    end
  end

  @doc """
    Writes token info to database queue to send that to Multichain service later.

    ## Parameters
    - `entries`: A map of token entries with data prepared with one of the `prepare_token_*` functions.
    - `entries_type`: A type of the token entries.

    ## Returns
    # - `:ok` if the data is accepted for insertion.
    # - `:ignore` if the Multichain service is not used.
  """
  @spec send_token_info_to_queue(%{binary() => map()}, :metadata | :total_supply | :counters | :market_data) ::
          :ok | :ignore
  def send_token_info_to_queue(entries, entries_type) do
    if enabled?() do
      entries
      |> extract_token_info_entries_into_chunks(entries_type)
      |> Enum.each(fn chunk ->
        Repo.insert_all(
          TokenInfoExportQueue,
          Helper.add_timestamps(chunk),
          on_conflict: {:replace, [:data, :updated_at]},
          conflict_target: [:address_hash, :data_type]
        )
      end)

      :ok
    else
      :ignore
    end
  end

  @spec extract_token_info_entries_into_chunks(
          %{binary() => map()},
          :metadata | :total_supply | :counters | :market_data
        ) :: list()
  defp extract_token_info_entries_into_chunks(entries, entries_type) do
    entries
    |> Enum.map(fn {address_hash, data} ->
      %{
        address_hash: address_hash,
        data_type: entries_type,
        data: data
      }
    end)
    |> Enum.chunk_every(token_info_chunk_size())
  end

  @doc """
    Writes counters to database queue to send those to Multichain service later.

    ## Parameters
    - `entries`: A map of counter entries.
    - `entries_type`: A type of the counter entries.

    ## Returns
    # - `:ok` if the data is accepted for insertion.
    # - `:ignore` if the Multichain service is not used.
  """
  @spec send_counters_to_queue(%{DateTime.t() => map()}, :global) :: :ok | :ignore
  def send_counters_to_queue(entries, entries_type) do
    if enabled?() do
      entries
      |> extract_counter_entries_into_chunks(entries_type)
      |> Enum.each(fn chunk ->
        Repo.insert_all(
          CountersExportQueue,
          Helper.add_timestamps(chunk),
          on_conflict: {:replace, [:data, :updated_at]},
          conflict_target: [:timestamp, :counter_type]
        )
      end)

      :ok
    else
      :ignore
    end
  end

  # Takes a map of counter entries and makes a list of the entries divided into chunks.
  # The chunk max size is defined by `MICROSERVICE_MULTICHAIN_SEARCH_COUNTERS_CHUNK_SIZE` env variable.
  #
  # ## Parameters
  # - `entries`: A map of the counter entries.
  # - `entries_type`: A type of the counter entries.
  #
  # ## Returns
  # - A list of chunks with the entries.
  @spec extract_counter_entries_into_chunks(%{DateTime.t() => map()}, :global) :: list()
  defp extract_counter_entries_into_chunks(entries, entries_type) do
    entries
    |> Enum.map(fn {timestamp, data} ->
      %{
        timestamp: timestamp,
        counter_type: entries_type,
        data: data
      }
    end)
    |> Enum.chunk_every(counters_chunk_size())
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

    balances_queue = compose_balances_queue(address_coin_balances, address_token_balances)

    {main_queue, balances_queue}
  end

  defp prepare_export_data_for_queue(%{
         address_coin_balances: address_coin_balances,
         address_token_balances: address_token_balances
       }) do
    balances_queue = compose_balances_queue(address_coin_balances, address_token_balances)

    {[], balances_queue}
  end

  defp compose_balances_queue(address_coin_balances, address_token_balances) do
    coin_balances_queue =
      address_coin_balances
      |> Enum.map(fn %{address_hash: address_hash, value: value} ->
        %{
          address_hash: address_hash |> Chain.string_to_address_hash() |> elem(1),
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
          address_hash: address_hash |> Chain.string_to_address_hash() |> elem(1),
          token_contract_address_hash_or_native: Helper.hash_to_binary(token_address_hash),
          # value is of Wei type in Explorer.Chain.Address.CoinBalance
          # value is of Decimal type in Explorer.Chain.Address.TokenBalance
          value: if(Decimal.is_decimal(value), do: value |> Wei.cast() |> elem(1), else: value),
          token_id: token_id
        }
      end)

    coin_balances_queue ++ token_balances_queue
  end

  @spec http_post_request(String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HttpClient.post(url, Jason.encode!(body), headers,
           recv_timeout: @post_timeout,
           pool: false
         ) do
      {:ok, %{body: response_body, status_code: 200}} ->
        response_body |> Jason.decode()

      {:ok, %{body: response_body, status_code: status_code}} ->
        {:error,
         %{
           url: url,
           data_to_retry: body,
           status_code: status_code,
           response_body: response_body
         }}

      {:error, reason} ->
        {:error,
         %{
           url: url,
           data_to_retry: body,
           reason: reason
         }}
    end
  end

  @doc """
  Extracts and organizes batch import parameters into chunks suitable for microservice requests.

  Given a map of parameters, this function:
  - Uniquely formats and chunks addresses.
  - Prepares block ranges and hashes (from blocks, block hashes, and transactions).
  - Associates each chunk with the current API key and chain ID.
  - Ensures that the first chunk includes all block ranges and hashes, while subsequent chunks only contain address data.

  Returns a list of maps, each representing a chunk of import parameters with the following structure:
    - `:api_key` - The API key as a string.
    - `:chain_id` - The chain ID as a string.
    - `:addresses` - A list of formatted address strings.
    - `:block_ranges` - A list of maps with `:min_block_number` and `:max_block_number` as strings.
    - `:hashes` - A list of maps with `:hash` and `:hash_type` as strings.

  If there are no addresses, a single chunk is returned containing only the hashes and block ranges.
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

    {addresses, coin_balances_from_addresses_list} =
      params
      |> Map.get(:addresses, [])
      |> Repo.preload([:token, :smart_contract])
      |> Enum.reduce({[], []}, fn address, {acc_addresses, acc_coin_balances} ->
        {[format_address(address) | acc_addresses], [format_address_coin_balance(address) | acc_coin_balances]}
      end)

    address_coin_balances =
      if Map.has_key?(params, :address_coin_balances) do
        params.address_coin_balances
        |> Enum.map(fn address_coin_balance ->
          %{
            address_hash: Hash.to_string(address_coin_balance.address_hash),
            token_contract_address_hash_or_native: "native",
            value: address_coin_balance.value
          }
        end)
      else
        coin_balances_from_addresses_list
      end

    block_hashes =
      if Map.has_key?(params, :block_hashes),
        do: format_block_hashes(params.block_hashes),
        else: format_blocks(Map.get(params, :blocks, []))

    transaction_hashes = format_transactions(Map.get(params, :transactions, []))

    block_transaction_hashes = block_hashes ++ transaction_hashes

    indexed_addresses_chunks =
      addresses
      |> Enum.sort_by(& &1.hash)
      |> Enum.uniq()
      |> Enum.chunk_every(addresses_chunk_size())
      |> Enum.with_index()

    indexed_address_coin_balances_chunks =
      address_coin_balances
      |> Enum.sort_by(& &1.address_hash)
      |> Enum.uniq()
      |> Enum.reject(&is_nil(&1.value))
      |> Enum.chunk_every(addresses_chunk_size())
      |> Enum.with_index()

    address_token_balances =
      cond do
        Map.has_key?(params, :address_current_token_balances) ->
          params.address_current_token_balances
          |> Enum.map(&format_address_token_balance/1)

        Map.has_key?(params, :address_token_balances) ->
          params.address_token_balances
          |> Enum.map(fn address_token_balance ->
            %{
              address_hash: Hash.to_string(address_token_balance.address_hash),
              token_address_hash: address_token_balance.token_contract_address_hash,
              token_id: address_token_balance.token_id,
              value: address_token_balance.value
            }
          end)

        true ->
          []
      end

    sanitized_address_token_balances =
      address_token_balances
      |> Enum.reject(&(is_nil(&1.value) && is_nil(&1.token_id)))

    api_key = api_key()
    chain_id = ChainId.get_id()
    chain_id_string = to_string(chain_id)

    base_data_chunk = %{
      api_key: api_key,
      chain_id: chain_id_string,
      addresses: [],
      block_ranges: [],
      hashes: [],
      address_token_balances: [],
      address_coin_balances: []
    }

    prepare_chunk(indexed_addresses_chunks, indexed_address_coin_balances_chunks, base_data_chunk, %{
      block_transaction_hashes: block_transaction_hashes,
      block_ranges: block_ranges,
      address_token_balances: sanitized_address_token_balances
    })
  end

  defp address_token_balances_chunk_by_index(address_token_balances, 0), do: address_token_balances

  defp address_token_balances_chunk_by_index(_address_token_balances, _index), do: []

  defp prepare_chunk([], [], base_data_chunk, %{
         block_transaction_hashes: block_transaction_hashes,
         block_ranges: block_ranges,
         address_token_balances: address_token_balances
       }) do
    [
      base_data_chunk
      |> Map.put(:hashes, block_transaction_hashes)
      |> Map.put(:block_ranges, block_ranges)
      |> Map.put(:address_token_balances, address_token_balances)
    ]
  end

  defp prepare_chunk(indexed_addresses_chunks, indexed_address_coin_balances_chunks, base_data_chunk, %{
         block_transaction_hashes: block_transaction_hashes,
         block_ranges: block_ranges,
         address_token_balances: address_token_balances
       })
       when indexed_addresses_chunks != [] do
    Enum.map(indexed_addresses_chunks, fn {addresses_chunk, index} ->
      # credo:disable-for-lines:3 Credo.Check.Refactor.Nesting
      hashes_in_chunk = if index == 0, do: block_transaction_hashes, else: []
      block_ranges_in_chunk = if index == 0, do: block_ranges, else: []
      address_token_balances_in_chunk = address_token_balances_chunk_by_index(address_token_balances, index)

      address_coin_balances_chunk =
        case Enum.fetch(indexed_address_coin_balances_chunks, index) do
          {:ok, {chunk, ^index}} when is_list(chunk) -> chunk
          _ -> []
        end

      base_data_chunk
      |> Map.put(:addresses, addresses_chunk)
      |> Map.put(
        :address_coin_balances,
        address_coin_balances_chunk
      )
      |> Map.put(:hashes, hashes_in_chunk)
      |> Map.put(:block_ranges, block_ranges_in_chunk)
      |> Map.put(:address_token_balances, address_token_balances_in_chunk)
    end)
  end

  defp prepare_chunk(_indexed_addresses_chunks, indexed_address_coin_balances_chunks, base_data_chunk, %{
         address_token_balances: address_token_balances
       })
       when indexed_address_coin_balances_chunks != [] do
    Enum.map(indexed_address_coin_balances_chunks, fn {indexed_address_coin_balance_chunk, index} ->
      address_token_balances_in_chunk = address_token_balances_chunk_by_index(address_token_balances, index)

      base_data_chunk
      |> Map.put(
        :address_coin_balances,
        indexed_address_coin_balance_chunk
      )
      |> Map.put(:address_token_balances, address_token_balances_in_chunk)
    end)
  end

  defp format_address(address) do
    %{
      hash: Hash.to_string(address.hash),
      is_contract: !is_nil(address.contract_code),
      is_verified_contract: address.verified,
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

  defp get_smart_contract_name(nil), do: nil

  defp get_smart_contract_name(%NotLoaded{}), do: nil

  defp get_smart_contract_name(smart_contract), do: smart_contract.name

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

  defp token_info_chunk_size do
    Application.get_env(:explorer, __MODULE__)[:token_info_chunk_size]
  end

  defp counters_chunk_size do
    Application.get_env(:explorer, __MODULE__)[:counters_chunk_size]
  end
end
