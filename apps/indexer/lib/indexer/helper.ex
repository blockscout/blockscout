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
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader, as: ContractReader

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

  @spec address_correct?(binary()) :: boolean()
  def address_correct?(address) when is_binary(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  def address_correct?(_address) do
    false
  end

  @doc """
  Fetches block number by its tag (e.g. `latest` or `safe`) using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_number_by_tag(binary(), list(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries \\ 3) do
    error_message = &"Cannot fetch #{tag} block number. Error: #{inspect(&1)}"
    repeated_call(&fetch_block_number_by_tag/2, [tag, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Fetches transaction data by its hash using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_transaction_by_hash(binary() | nil, list(), non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

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
  TBD
  """
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
  Forms JSON RPC named arguments for the given RPC URL.
  """
  @spec build_json_rpc_named_arguments(binary()) :: EthereumJSONRPC.json_rpc_named_arguments()
  def build_json_rpc_named_arguments(rpc_url) do
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
          binary()
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
  TBD
  """
  def read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left) when retries_left > 0 do
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

    if Enum.empty?(error_messages) do
      {responses, []}
    else
      retries_left = retries_left - 1

      if retries_left == 0 do
        {responses, Enum.uniq(error_messages)}
      else
        Logger.error("#{List.first(error_messages)}. Retrying...")
        :timer.sleep(3000)
        read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left)
      end
    end
  end

  @doc """
  TBD
  """
  def repeated_batch_call(func, args, error_message, retries_left) do
    # credo:disable-for-previous-line Credo.Check.Refactor.CyclomaticComplexity
    case apply(func, args) do
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
          Logger.error(error_message.(message))
          responses_or_error
        else
          Logger.error("#{error_message.(message)} Retrying...")
          :timer.sleep(3000)
          repeated_batch_call(func, args, error_message, retries_left)
        end
    end
  end

  @doc """
  Calls the given function with the given arguments
  until it returns {:ok, any()} or the given attempts number is reached.
  Pauses execution between invokes for 3 seconds.
  """
  @spec repeated_call((... -> any()), list(), (... -> any()), non_neg_integer()) ::
          {:ok, any()} | {:error, binary() | atom()}
  def repeated_call(func, args, error_message, retries_left) do
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
          :timer.sleep(3000)
          repeated_call(func, args, error_message, retries_left)
        end
    end
  end

  @doc """
  Fetches block timestamp by its number using RPC request.
  Performs a specified number of retries (up to) if the first attempt returns error.
  """
  @spec get_block_timestamp_by_number(non_neg_integer(), list(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries \\ 3) do
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
