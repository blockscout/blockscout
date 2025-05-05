defmodule Indexer.Helper do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  require Logger

  import EthereumJSONRPC,
    only: [
      fetch_block_number_by_tag: 2,
      id_to_params: 1,
      integer_to_quantity: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Helper, only: [hash_to_binary: 1]

  alias EthereumJSONRPC.Block.{ByNumber, ByTag}
  alias EthereumJSONRPC.{Blocks, Transport}
  alias Explorer.Chain.Beacon.Blob, as: BeaconBlob
  alias Explorer.Chain.Cache.LatestL1BlockNumber
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader, as: ContractReader
  alias Indexer.Fetcher.Beacon.Blob, as: BeaconBlobFetcher
  alias Indexer.Fetcher.Beacon.Client, as: BeaconClient

  @finite_retries_number 3
  @infinite_retries_number 100_000_000
  @block_check_interval_range_size 100
  @block_by_number_chunk_size 50

  @beacon_blob_fetcher_reference_slot_eth 8_500_000
  @beacon_blob_fetcher_reference_timestamp_eth 1_708_824_023
  @beacon_blob_fetcher_reference_slot_sepolia 4_400_000
  @beacon_blob_fetcher_reference_timestamp_sepolia 1_708_533_600
  @beacon_blob_fetcher_reference_slot_holesky 1_000_000
  @beacon_blob_fetcher_reference_timestamp_holesky 1_707_902_400
  @beacon_blob_fetcher_slot_duration 12
  @chain_id_eth 1
  @chain_id_sepolia 11_155_111
  @chain_id_holesky 17000

  @doc """
  Checks whether the given Ethereum address looks correct.
  The address should begin with 0x prefix and then contain 40 hexadecimal digits (can be in mixed case).
  This function doesn't check if the address is checksummed.
  """
  @spec address_correct?(binary()) :: boolean()
  def address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def address_correct?(_address) do
    false
  end

  @doc """
  Converts Explorer.Chain.Hash representation of the given address to a string
  beginning with 0x prefix. If the given address is already a string, it is not modified.
  The second argument forces the result to be downcased.
  """
  @spec address_hash_to_string(binary(), boolean()) :: binary()
  def address_hash_to_string(hash, downcase \\ false)

  def address_hash_to_string(hash, downcase) when is_binary(hash) do
    if downcase do
      String.downcase(hash)
    else
      hash
    end
  end

  def address_hash_to_string(hash, downcase) do
    if downcase do
      String.downcase(Hash.to_string(hash))
    else
      Hash.to_string(hash)
    end
  end

  @doc """
    Converts a Unix timestamp to a `DateTime`.

    If the given timestamp is `nil` or `0`, it returns the Unix epoch start.
    If the conversion fails, it also returns the Unix epoch start.

    ## Parameters
    - `time_ts`: A non-negative integer representing the Unix timestamp or `nil`.

    ## Returns
    - A `DateTime` corresponding to the given Unix timestamp, or the Unix epoch start if
      the timestamp is `nil`, `0`, or if the conversion fails.
  """
  @spec timestamp_to_datetime(non_neg_integer() | nil) :: DateTime.t()
  def timestamp_to_datetime(time_ts) do
    {_, unix_epoch_starts} = DateTime.from_unix(0)

    case is_nil(time_ts) or time_ts == 0 do
      true ->
        unix_epoch_starts

      false ->
        case DateTime.from_unix(time_ts) do
          {:ok, datetime} ->
            datetime

          {:error, _} ->
            unix_epoch_starts
        end
    end
  end

  @doc """
  Calculates average block time in milliseconds (based on the latest 100 blocks) divided by 2.
  Sends corresponding requests to the RPC node.
  Returns a tuple {:ok, block_check_interval, last_safe_block}
  where `last_safe_block` is the number of the recent `safe` or `latest` block (depending on which one is available).
  Returns {:error, description} in case of error.
  """
  @spec get_block_check_interval(list()) :: {:ok, non_neg_integer(), non_neg_integer()} | {:error, any()}
  def get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           get_block_timestamp_by_number_or_tag(first_block, json_rpc_named_arguments, @infinite_retries_number),
         {:ok, last_safe_block_timestamp} <-
           get_block_timestamp_by_number_or_tag(last_safe_block, json_rpc_named_arguments, @infinite_retries_number) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, last_safe_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  @doc """
    Retrieves the safe block if the endpoint supports such an interface; otherwise, it requests the latest block.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    `{block_number, latest}`: A tuple where
    - `block_number` is the safe or latest block number.
    - `latest` is a boolean, where `true` indicates that `block_number` is the latest block number fetched using the tag `latest`.
  """
  @spec get_safe_block(EthereumJSONRPC.json_rpc_named_arguments()) :: {non_neg_integer(), boolean()}
  def get_safe_block(json_rpc_named_arguments) do
    case get_block_number_by_tag("safe", json_rpc_named_arguments) do
      {:ok, safe_block} ->
        {safe_block, false}

      {:error, _} ->
        {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, @infinite_retries_number)

        {latest_block, true}
    end
  end

  @doc """
  Fetches block number by its tag (e.g. `latest` or `safe`) using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_number_by_tag(binary(), list(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ @finite_retries_number) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Fetches transaction data by its hash using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_transaction_by_hash(binary() | nil, list(), non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ @finite_retries_number)

  def get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    error_message = &"eth_getTransactionByHash failed. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
    Returns a number of attempts for RPC requests sending by indexer modules.
    The number is defined by @finite_retries_number attribute.
  """
  @spec finite_retries_number() :: non_neg_integer()
  def finite_retries_number do
    @finite_retries_number
  end

  @doc """
    Returns a big number of attempts for RPC requests sending by indexer modules
    (simulating an infinite number of attempts). The number is defined by
    @infinite_retries_number attribute.
  """
  @spec infinite_retries_number() :: non_neg_integer()
  def infinite_retries_number do
    @infinite_retries_number
  end

  @doc """
  Forms JSON RPC named arguments for the given RPC URL.
  """
  @spec json_rpc_named_arguments(binary()) :: list()
  def json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        urls: [rpc_url],
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  @doc """
  Splits a given range into chunks of the specified size.

  ## Parameters
  - `range`: The range to be split into chunks.
  - `chunk_size`: The size of each chunk.

  ## Returns
  - A stream of ranges, each representing a chunk of the specified size.

  ## Examples

      iex> Indexer.Helper.range_chunk_every(1..10, 3)
      #Stream<...>

      iex> Enum.to_list(Indexer.Helper.range_chunk_every(1..10, 3))
      [1..3, 4..6, 7..9, 10..10]
  """
  @spec range_chunk_every(Range.t(), non_neg_integer()) :: Enum.t()
  def range_chunk_every(from..to//_, chunk_size) do
    chunks_number = floor((to - from + 1) / chunk_size)

    0..chunks_number
    |> Stream.map(fn current_chunk ->
      chunk_start = from + chunk_size * current_chunk
      chunk_end = min(chunk_start + chunk_size - 1, to)
      chunk_start..chunk_end
    end)
  end

  @doc """
    Retrieves event logs from Ethereum-like blockchains within a specified block
    range for a given address and set of topics using JSON-RPC.

    ## Parameters
    - `from_block`: The starting block number (integer or hexadecimal string) for the log search.
    - `to_block`: The ending block number (integer or hexadecimal string) for the log search.
    - `address`: The address of the contract to filter logs from.
    - `topics`: List of topics to filter the logs. The list represents each topic as follows:
                [topic0, topic1, topic2, topic3]. The `topicN` can be either some value or
                a list of possible values, e.g.: [[topic0_1, topic0_2], topic1, topic2, topic3].
                If a topic is omitted or `nil`, it doesn't take part in the logs filtering.
    - `json_rpc_named_arguments`: Configuration for the JSON-RPC call.
    - `id`: (optional) JSON-RPC request identifier, defaults to 0.
    - `retries`: (optional) Number of retry attempts if the request fails, defaults to 3.

    ## Returns
    - `{:ok, logs}` on successful retrieval of logs.
    - `{:error, reason}` if the request fails after all retries.
  """
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          [binary()] | [list()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:error, atom() | binary() | map()} | {:ok, any()}
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          [binary()] | [list()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer()
        ) :: {:error, atom() | binary() | map()} | {:ok, any()}
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          [binary()] | [list()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer(),
          non_neg_integer()
        ) :: {:error, atom() | binary() | map()} | {:ok, any()}
  def get_logs(from_block, to_block, address, topics, json_rpc_named_arguments, id \\ 0, retries \\ 3) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: id,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => topics
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Prints a log of progress when handling something splitted to block chunks.
  """
  @spec log_blocks_chunk_handling(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          binary() | nil,
          :L1 | :L2
        ) :: :ok
  def log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, items_count, layer) do
    is_start = is_nil(items_count)

    {type, found} =
      if is_start do
        {"Start", ""}
      else
        {"Finish", " Found #{items_count}."}
      end

    target_range =
      if chunk_start != start_block or chunk_end != end_block do
        progress =
          if is_start do
            ""
          else
            percentage =
              (chunk_end - start_block + 1)
              |> Decimal.div(end_block - start_block + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_block}..#{end_block}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling #{layer} block ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling #{layer} block range #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  @doc """
    Retrieves decoded results of `eth_call` requests to contracts, with retry
    logic for handling errors.

    The function attempts the specified number of retries, with a progressive
    delay between each retry, for each `eth_call` request. If, after all
    retries, some requests remain unsuccessful, it returns a list of unique
    error messages encountered.

    ## Parameters
    - `requests`: A list of `EthereumJSONRPC.Contract.call()` instances
                  describing the parameters for `eth_call`, including the
                  contract address and method selector.
    - `abi`: A list of maps providing the ABI that describes the input
             parameters and output format for the contract functions.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
                                  connection.
    - `retries_left`: The number of retries allowed for any `eth_call` that
                      returns an error.
    - `log_error?` (optional):  A boolean indicating whether to log error
                               messages on retries. Defaults to `true`.

    ## Returns
    - `{responses, errors}` where:
      - `responses`: A list of tuples `{status, result}`, where `result` is the
                     decoded response from the corresponding `eth_call` if
                     `status` is `:ok`, or the error message if `status` is
                     `:error`.
      - `errors`: A list of error messages, if any element in `responses`
        contains `:error`.
  """
  @spec read_contracts_with_retries(
          [EthereumJSONRPC.Contract.call()],
          [map()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer()
        ) :: {[{:ok | :error, any()}], list()}
  def read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, log_error? \\ true)
      when is_list(requests) and is_list(abi) and is_integer(retries_left) do
    do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, 0, log_error?)
  end

  defp do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, retries_done, log_error?) do
    responses = ContractReader.query_contracts(requests, abi, json_rpc_named_arguments: json_rpc_named_arguments)

    error_messages =
      Enum.reduce(responses, [], fn {status, error_message}, acc ->
        acc ++
          if status == :error do
            [error_message]
          else
            []
          end
      end)

    retries_left = retries_left - 1

    cond do
      error_messages == [] ->
        {responses, []}

      retries_left <= 0 ->
        if log_error?, do: Logger.error("#{List.first(error_messages)}.")
        {responses, Enum.uniq(error_messages)}

      true ->
        if log_error?, do: Logger.error("#{List.first(error_messages)}. Retrying...")
        pause_before_retry(retries_done)

        do_read_contracts_with_retries(
          requests,
          abi,
          json_rpc_named_arguments,
          retries_left,
          retries_done + 1,
          log_error?
        )
    end
  end

  @doc """
    Executes a batch of RPC calls with retry logic for handling errors.

    This function performs a batch of RPC calls, retrying a specified number of times
    with a progressive delay between each attempt up to a maximum (20 minutes). If,
    after all retries, some calls remain unsuccessful, it returns the batch responses,
    which include the results of successful calls or error descriptions.

    ## Parameters
    - `requests`: A list of `Transport.request()` instances describing the RPC calls.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `error_message_generator`: A function that generates a string containing the error
                                 message returned by the RPC call.
    - `max_retries`: The number of retries allowed for any RPC call that returns an error.

    ## Returns
    - `{:ok, responses}`: When all calls are successful, `responses` is a list of standard
                          JSON responses, each including `id` and `result` fields.
    - `{:error, responses}`: When some calls fail, `responses` is a list containing either
                             standard JSON responses for successful calls (including `id`
                             and `result` fields) or errors, which may be in an unassured
                             format.
  """
  @spec repeated_batch_rpc_call([Transport.request()], EthereumJSONRPC.json_rpc_named_arguments(), fun(), integer()) ::
          {:error, any()} | {:ok, any()}
  def repeated_batch_rpc_call(requests, json_rpc_named_arguments, error_message_generator, max_retries)
      when is_list(requests) and is_function(error_message_generator) and is_integer(max_retries) do
    do_repeated_batch_rpc_call(requests, json_rpc_named_arguments, error_message_generator, max_retries, 0)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp do_repeated_batch_rpc_call(
         requests,
         json_rpc_named_arguments,
         error_message_generator,
         retries_left,
         retries_done
       ) do
    requests
    |> json_rpc(json_rpc_named_arguments)
    |> case do
      {:ok, responses_list} = batch_responses ->
        standardized_error =
          Enum.reduce_while(responses_list, %{}, fn one_response, acc ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case one_response do
              %{error: error_msg_with_code} -> {:halt, error_msg_with_code}
              _ -> {:cont, acc}
            end
          end)

        case standardized_error do
          %{code: _, message: error_msg} -> {:error, error_msg, batch_responses}
          _ -> {:ok, batch_responses, []}
        end

      {:error, message} = err ->
        {:error, message, err}
    end
    |> case do
      {:ok, responses, _} ->
        responses

      {:error, message, responses_or_error} ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message_generator.(message))
          responses_or_error
        else
          Logger.error("#{error_message_generator.(message)} Retrying...")
          pause_before_retry(retries_done)

          do_repeated_batch_rpc_call(
            requests,
            json_rpc_named_arguments,
            error_message_generator,
            retries_left,
            retries_done + 1
          )
        end
    end
  end

  @doc """
    Repeatedly executes a specified function with given arguments until it succeeds
    or reaches the limit of retry attempts. It pauses between retries, with the
    pause duration increasing progressively up to a maximum (20 minutes).

    The main intent of the function is to robustly handle RPC calls that may fail.

    ## Parameters
    - `func`: The function to be called.
    - `args`: List of arguments to pass to the function.
    - `error_message`: A function that takes an error message and returns a log message.
    - `retries_left`: The number of attempts left.
    - `retries_done`: (optional) The number of attempts already made, defaults to 0.

    ## Returns
    - `{:ok, result}` on success.
    - `{:error, reason}` if retries are exhausted without success.
  """
  @spec repeated_call(function(), list(), function(), non_neg_integer()) ::
          {:ok, any()} | {:error, binary() | atom() | map()}
  @spec repeated_call(function(), list(), function(), non_neg_integer(), non_neg_integer()) ::
          {:ok, any()} | {:error, binary() | atom() | map()}
  def repeated_call(func, args, error_message, retries_left, retries_done \\ 0) do
    case apply(func, args) do
      {:ok, _} = res ->
        res

      {:error, message} = err ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          Logger.error(error_message.(message))
          err
        else
          Logger.error("#{error_message.(message)} Retrying...")
          pause_before_retry(retries_done)
          repeated_call(func, args, error_message, retries_left, retries_done + 1)
        end
    end
  end

  @doc """
    Fetches blocks info from the given list of events (logs).
    Performs a specified number of retries (up to) if the first attempt returns error.

    ## Parameters
    - `events`: The list of events to retrieve block numbers from.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `retries`: Number of retry attempts if the request fails.
    - `transaction_details`: Whether to include transaction details into the resulting list of blocks.

    ## Returns
    - The list of blocks. The list is empty if the HTTP response returns error.
  """
  @spec get_blocks_by_events(list(), EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer(), boolean()) :: [
          %{String.t() => any()}
        ]
  def get_blocks_by_events(events, json_rpc_named_arguments, retries, transaction_details \\ false) do
    events
    |> Enum.reduce(%{}, fn event, acc ->
      block_number = Map.get(event, :block_number, event["blockNumber"])
      Map.put(acc, block_number, 0)
    end)
    |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
    |> id_to_params()
    |> Blocks.requests(&ByNumber.request(&1, transaction_details, false))
    |> Enum.chunk_every(@block_by_number_chunk_size)
    |> Enum.reduce([], fn current_requests, results_acc ->
      error_message =
        &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(current_requests)}"

      # credo:disable-for-lines:3 Credo.Check.Refactor.Nesting
      results =
        case repeated_call(&json_rpc/2, [current_requests, json_rpc_named_arguments], error_message, retries) do
          {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
          {:error, _} -> []
        end

      results_acc ++ results
    end)
  end

  @doc """
  Fetches block timestamp by its number using RPC request.
  The number can be `:latest`.
  Performs a specified number of retries (up to) if the first attempt returns error.

  ## Parameters
  - `number`: Block number or `:latest` to fetch the latest block.
  - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  - `retries`: Number of retry attempts if the request fails.

  ## Returns
  - `{:ok, timestamp}` where `timestamp` is the block timestamp as a Unix timestamp.
  - `{:error, reason}` if the request fails after all retries.
  """
  @spec get_block_timestamp_by_number_or_tag(non_neg_integer() | :latest, list(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def get_block_timestamp_by_number_or_tag(number, json_rpc_named_arguments, retries \\ @finite_retries_number) do
    func = &get_block_timestamp_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  defp get_block_timestamp_inner(number, json_rpc_named_arguments) do
    request =
      if number == :latest do
        ByTag.request(%{id: 0, tag: "latest"})
      else
        ByNumber.request(%{id: 0, number: number}, false)
      end

    result = json_rpc(request, json_rpc_named_arguments)

    with {:ok, block} <- result,
         false <- is_nil(block),
         timestamp <- Map.get(block, "timestamp"),
         false <- is_nil(timestamp) do
      {:ok, quantity_to_integer(timestamp)}
    else
      {:error, message} ->
        {:error, message}

      true ->
        {:error, "RPC returned nil."}
    end
  end

  @doc """
  Converts a log topic from Hash.Full representation to string one.
  """
  @spec log_topic_to_string(any()) :: binary() | nil
  def log_topic_to_string(topic) do
    if is_binary(topic) or is_nil(topic) do
      topic
    else
      Hash.to_string(topic)
    end
  end

  @doc """
  Pauses the process, incrementally increasing the sleep time up to a maximum of 20 minutes.

  ## Parameters
  - `retries_done`: How many retries have already been done.

  ## Returns
  - Nothing.
  """
  @spec pause_before_retry(non_neg_integer()) :: :ok
  def pause_before_retry(retries_done) do
    :timer.sleep(min(3000 * Integer.pow(2, retries_done), 1_200_000))
  end

  @doc """
    Fetches the `latest` block number from L1. If the block number is cached in `Explorer.Chain.Cache.LatestL1BlockNumber`,
    the cached value is used. The cached value is updated in `Indexer.Fetcher.RollupL1ReorgMonitor` module.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection on L1.

    ## Returns
    - The block number.
  """
  @spec fetch_latest_l1_block_number(EthereumJSONRPC.json_rpc_named_arguments()) :: non_neg_integer()
  def fetch_latest_l1_block_number(json_rpc_named_arguments) do
    case LatestL1BlockNumber.get_block_number() do
      nil ->
        {:ok, latest} =
          get_block_number_by_tag("latest", json_rpc_named_arguments, @infinite_retries_number)

        latest

      latest_from_cache ->
        latest_from_cache
    end
  end

  @doc """
    Sends HTTP GET request to the given URL and returns JSON response. Makes max 10 attempts and then returns an error in case of failure.
    There is a timeout between attempts (increasing from 3 seconds to 20 minutes max as the number of attempts increases).

    ## Parameters
    - `url`: The URL which needs to be requested.
    - `attempts_done`: The number of attempts done. Incremented by the function itself.

    ## Returns
    - `{:ok, response}` where `response` is a map decoded from a JSON object.
    - `{:error, reason}` in case of failure (after three unsuccessful attempts).
  """
  @spec http_get_request(String.t(), non_neg_integer()) :: {:ok, map()} | {:error, any()}
  def http_get_request(url, attempts_done \\ 0) do
    recv_timeout = 5_000
    connect_timeout = 8_000
    client = Tesla.client([{Tesla.Middleware.Timeout, timeout: recv_timeout}], Tesla.Adapter.Mint)

    case Tesla.get(client, url, opts: [adapter: [timeout: recv_timeout, transport_opts: [timeout: connect_timeout]]]) do
      {:ok, %{body: body, status: 200}} ->
        Jason.decode(body)

      {:ok, %{body: body, status: _}} ->
        http_get_request_error(url, body, attempts_done)

      {:error, error} ->
        http_get_request_error(url, error, attempts_done)
    end
  end

  # Handles HTTP GET error and tries to re-call the `http_get_request` function after sleep.
  #
  # ## Parameters
  # - `url`: The URL which needs to be requested.
  # - `error`: The error description for logging purposes.
  # - `attempts_done`: The number of attempts done. Incremented by the function itself.
  #
  # ## Returns
  # - `{:ok, response}` tuple if the re-call was successful.
  # - `{:error, reason}` if all attempts were failed.
  @spec http_get_request_error(String.t(), any(), non_neg_integer()) :: {:ok, map()} | {:error, any()}
  defp http_get_request_error(url, error, attempts_done) do
    old_truncate = Application.get_env(:logger, :truncate)
    Logger.configure(truncate: :infinity)

    Logger.error(fn ->
      [
        "Error while sending request to #{url}: ",
        inspect(error, limit: :infinity, printable_limit: :infinity)
      ]
    end)

    Logger.configure(truncate: old_truncate)

    # retry to send the request
    attempts_done = attempts_done + 1

    if attempts_done < 10 do
      # wait up to 20 minutes and then retry
      :timer.sleep(min(3000 * Integer.pow(2, attempts_done - 1), 1_200_000))
      Logger.info("Retry to send the request to #{url} ...")
      http_get_request(url, attempts_done)
    else
      {:error, "Error while sending request to #{url}"}
    end
  end

  @doc """
    Sends an HTTP request to Beacon Node to get EIP-4844 blob data by blob's versioned hash.

    ## Parameters
    - `blob_hash`: The blob versioned hash in form of `0x` string.
    - `l1_block_timestamp`: Timestamp of L1 block to convert it to beacon slot.
    - `l1_chain_id`: ID of L1 chain to automatically define parameters for calculating beacon slot.
      If ID is `nil` or unknown, the parameters are taken from the fallback INDEXER_BEACON_BLOB_FETCHER_REFERENCE_SLOT,
      INDEXER_BEACON_BLOB_FETCHER_REFERENCE_TIMESTAMP, INDEXER_BEACON_BLOB_FETCHER_SLOT_DURATION env variables.

    ## Returns
    - A binary with the blob data in case of success.
    - `nil` in case of failure.
  """
  @spec get_eip4844_blob_from_beacon_node(String.t(), DateTime.t(), non_neg_integer() | nil) :: binary() | nil
  def get_eip4844_blob_from_beacon_node(blob_hash, l1_block_timestamp, l1_chain_id) do
    beacon_config =
      case l1_chain_id do
        @chain_id_eth ->
          %{
            reference_slot: @beacon_blob_fetcher_reference_slot_eth,
            reference_timestamp: @beacon_blob_fetcher_reference_timestamp_eth,
            slot_duration: @beacon_blob_fetcher_slot_duration
          }

        @chain_id_sepolia ->
          %{
            reference_slot: @beacon_blob_fetcher_reference_slot_sepolia,
            reference_timestamp: @beacon_blob_fetcher_reference_timestamp_sepolia,
            slot_duration: @beacon_blob_fetcher_slot_duration
          }

        @chain_id_holesky ->
          %{
            reference_slot: @beacon_blob_fetcher_reference_slot_holesky,
            reference_timestamp: @beacon_blob_fetcher_reference_timestamp_holesky,
            slot_duration: @beacon_blob_fetcher_slot_duration
          }

        _ ->
          :indexer
          |> Application.get_env(BeaconBlobFetcher)
          |> Keyword.take([:reference_slot, :reference_timestamp, :slot_duration])
          |> Enum.into(%{})
      end

    sidecars_url =
      l1_block_timestamp
      |> DateTime.to_unix()
      |> BeaconBlobFetcher.timestamp_to_slot(beacon_config)
      |> BeaconClient.blob_sidecars_url()

    {:ok, fetched_blobs} = http_get_request(sidecars_url)

    blobs = Map.get(fetched_blobs, "data", [])

    if Enum.empty?(blobs) do
      raise "Empty data"
    end

    blobs
    |> Enum.find(fn b ->
      b
      |> Map.get("kzg_commitment", "0x")
      |> hash_to_binary()
      |> BeaconBlob.hash()
      |> Hash.to_string()
      |> Kernel.==(blob_hash)
    end)
    |> Map.get("blob")
    |> hash_to_binary()
  rescue
    reason ->
      Logger.warning("Cannot get the blob #{blob_hash} from the Beacon Node. Reason: #{inspect(reason)}")
      nil
  end

  @doc """
    Removes leading and trailing whitespaces and trailing slash (/) from URL string to prepare it
    for concatenation with another part of URL.

    ## Parameters
    - `url`: The source URL to be trimmed.

    ## Returns
    - Clear URL without trailing slash and leading and trailing whitespaces.
  """
  @spec trim_url(String.t()) :: String.t()
  def trim_url(url) do
    url
    |> String.trim()
    |> String.trim_trailing("/")
  end

  @max_queue_size 5000
  @busy_waiting_timeout 500
  @doc """
  Reduces the given `data` into an accumulator `acc` using the provided `reducer` function,
  but only if the queue is not full. This function ensures that the processing respects
  the queue's size constraints.

  If the queue is full (i.e., its size is greater than or equal to `@max_queue_size` or
  its `maximum_size`), the function will pause for a duration defined by `@busy_waiting_timeout`
  and retry until the queue has available space.

  ## Parameters

    - `data`: The data to be processed by the `reducer` function.
    - `acc`: The accumulator that will be passed to the `reducer` function.
    - `reducer`: A function that takes `data` and `acc` as arguments and returns the updated accumulator.

  ## Returns

  The result of applying the `reducer` function to the `data` and `acc`.

  ## Notes

  This function uses a recursive approach to wait for the queue to have available space.
  Ensure that the `@busy_waiting_timeout` is set to an appropriate value to avoid excessive delays.
  """
  @spec reduce_if_queue_is_not_full(any(), any(), (any(), any() -> any()), module()) :: any()
  def reduce_if_queue_is_not_full(data, acc, reducer, module) do
    bound_queue = GenServer.call(module, :state).bound_queue

    if bound_queue.size >= @max_queue_size or (bound_queue.maximum_size && bound_queue.size >= bound_queue.maximum_size) do
      :timer.sleep(@busy_waiting_timeout)

      reduce_if_queue_is_not_full(data, acc, reducer, module)
    else
      reducer.(data, acc)
    end
  end
end
