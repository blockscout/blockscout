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
      request: 1
    ]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.Hash

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

  defp get_safe_block(json_rpc_named_arguments) do
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
  Calls the given function with the given arguments
  until it returns {:ok, any()} or the given attempts number is reached.
  Pauses execution between invokes for 3..1200 seconds (depending on the number of retries).
  """
  @spec repeated_call((... -> any()), list(), (... -> any()), non_neg_integer()) ::
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

          # wait up to 20 minutes
          :timer.sleep(min(3000 * Integer.pow(2, retries_done), 1_200_000))

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
end
