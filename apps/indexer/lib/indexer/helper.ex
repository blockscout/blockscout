defmodule Indexer.Helper do
  @moduledoc """
  Auxiliary common functions for indexers.
  """

  require Logger

  import EthereumJSONRPC,
    only: [
      fetch_block_number_by_tag: 2,
      json_rpc: 2,
      quantity_to_integer: 1,
      integer_to_quantity: 1,
      request: 1
    ]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.{Blocks, Transport}
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader, as: ContractReader

  @finite_retries_number 3
  @infinite_retries_number 100_000_000
  @block_check_interval_range_size 100
  @block_by_number_chunk_size 50

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
           get_block_timestamp_by_number(first_block, json_rpc_named_arguments, 100_000_000),
         {:ok, last_safe_block_timestamp} <-
           get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments, 100_000_000) do
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
    `{block_num, latest}`: A tuple where
    - `block_num` is the safe or latest block number.
    - `latest` is a boolean, where `true` indicates that `block_num` is the latest block number fetched using the tag `latest`.
  """
  @spec get_safe_block(EthereumJSONRPC.json_rpc_named_arguments()) :: {non_neg_integer(), boolean()}
  def get_safe_block(json_rpc_named_arguments) do
    case get_block_number_by_tag("safe", json_rpc_named_arguments) do
      {:ok, safe_block} ->
        {safe_block, false}

      {:error, :not_found} ->
        {:ok, latest_block} = get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
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
        url: rpc_url,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  @doc """
    Retrieves event logs from Ethereum-like blockchains within a specified block
    range for a given address and set of topics using JSON-RPC.

    ## Parameters
    - `from_block`: The starting block number (integer or hexadecimal string) for the log search.
    - `to_block`: The ending block number (integer or hexadecimal string) for the log search.
    - `address`: The address of the contract to filter logs from.
    - `topics`: List of topics to filter the logs.
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
          [binary()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:error, atom() | binary() | map()} | {:ok, any()}
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          [binary()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer()
        ) :: {:error, atom() | binary() | map()} | {:ok, any()}
  @spec get_logs(
          non_neg_integer() | binary(),
          non_neg_integer() | binary(),
          binary(),
          [binary()],
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
    Retrieves decoded results of `eth_call` requests to contracts, with retry logic for handling errors.

    The function attempts the specified number of retries, with a progressive delay between
    each retry, for each `eth_call` request. If, after all retries, some requests remain
    unsuccessful, it returns a list of unique error messages encountered.

    ## Parameters
    - `requests`: A list of `EthereumJSONRPC.Contract.call()` instances describing the parameters
                  for `eth_call`, including the contract address and method selector.
    - `abi`: A list of maps providing the ABI that describes the input parameters and output
             format for the contract functions.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `retries_left`: The number of retries allowed for any `eth_call` that returns an error.

    ## Returns
    - `{responses, errors}` where:
      - `responses`: A list of tuples `{status, result}`, where `result` is the decoded response
                     from the corresponding `eth_call` if `status` is `:ok`, or the error message
                     if `status` is `:error`.
      - `errors`: A list of error messages, if any element in `responses` contains `:error`.
  """
  @spec read_contracts_with_retries(
          [EthereumJSONRPC.Contract.call()],
          [map()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          integer()
        ) :: {[{:ok | :error, any()}], list()}
  def read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left)
      when is_list(requests) and is_list(abi) and is_integer(retries_left) do
    do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, 0)
  end

  defp do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, retries_done) do
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

    if error_messages == [] do
      {responses, []}
    else
      retries_left = retries_left - 1

      if retries_left <= 0 do
        {responses, Enum.uniq(error_messages)}
      else
        Logger.error("#{List.first(error_messages)}. Retrying...")
        pause_before_retry(retries_done)
        do_read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left, retries_done + 1)
      end
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
    - `retries_left`: The number of retries allowed for any RPC call that returns an error.

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
  def repeated_batch_rpc_call(requests, json_rpc_named_arguments, error_message_generator, retries_left)
      when is_list(requests) and is_function(error_message_generator) and is_integer(retries_left) do
    do_repeated_batch_rpc_call(requests, json_rpc_named_arguments, error_message_generator, retries_left, 0)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp do_repeated_batch_rpc_call(
         requests,
         json_rpc_named_arguments,
         error_message_generator,
         retries_left,
         retries_done
       ) do
    case json_rpc(requests, json_rpc_named_arguments) do
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
      # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
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
  """
  @spec get_blocks_by_events(list(), list(), non_neg_integer()) :: list()
  def get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    events
    |> Enum.reduce(%{}, fn event, acc ->
      block_number = Map.get(event, :block_number, event["blockNumber"])
      Map.put(acc, block_number, 0)
    end)
    |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
    |> Stream.with_index()
    |> Enum.into(%{}, fn {params, id} -> {id, params} end)
    |> Blocks.requests(&ByNumber.request(&1, false, false))
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
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_timestamp_by_number(non_neg_integer(), list(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries \\ @finite_retries_number) do
    func = &get_block_timestamp_by_number_inner/2
    args = [number, json_rpc_named_arguments]
    error_message = &"Cannot fetch block ##{number} or its timestamp. Error: #{inspect(&1)}"
    repeated_call(func, args, error_message, retries)
  end

  defp get_block_timestamp_by_number_inner(number, json_rpc_named_arguments) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

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

  # Pauses the process, incrementally increasing the sleep time up to a maximum of 20 minutes.
  defp pause_before_retry(retries_done) do
    :timer.sleep(min(3000 * Integer.pow(2, retries_done), 1_200_000))
  end
end
