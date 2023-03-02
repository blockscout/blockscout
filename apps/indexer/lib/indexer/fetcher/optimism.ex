defmodule Indexer.Fetcher.Optimism do
  @moduledoc """
  Contains common functions for Optimism* fetchers.
  """

  require Logger

  import EthereumJSONRPC,
    only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, quantity_to_integer: 1, request: 1]

  alias ABI.TypeDecoder
  alias EthereumJSONRPC.Block.ByNumber
  alias Explorer.Chain.Data

  @eth_get_logs_range_size 1000

  def get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left \\ 3) do
    case fetch_block_number_by_tag(tag, json_rpc_named_arguments) do
      {:ok, block_number} ->
        {:ok, block_number}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch #{tag} block number. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_block_number_by_tag(tag, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left \\ 3) do
    result =
      %{id: 0, number: number}
      |> ByNumber.request(false)
      |> json_rpc(json_rpc_named_arguments)

    return =
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

    case return do
      {:ok, timestamp} ->
        {:ok, timestamp}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch block ##{number} or its timestamp. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_block_timestamp_by_number(number, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left) do
    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => integer_to_quantity(from_block),
            :toBlock => integer_to_quantity(to_block),
            :address => address,
            :topics => [topic0]
          }
        ]
      })

    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, results} ->
        {:ok, results}

      {:error, message} ->
        retries_left = retries_left - 1

        error_message = "Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(message)}"

        if retries_left <= 0 do
          Logger.error(error_message)
          {:error, message}
        else
          Logger.error("#{error_message} Retrying...")
          :timer.sleep(3000)
          get_logs(from_block, to_block, address, topic0, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left \\ 3)

  def get_transaction_by_hash(hash, _json_rpc_named_arguments, _retries_left) when is_nil(hash), do: {:ok, nil}

  def get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    case json_rpc(req, json_rpc_named_arguments) do
      {:ok, tx} ->
        {:ok, tx}

      {:error, message} ->
        retries_left = retries_left - 1

        if retries_left <= 0 do
          {:error, message}
        else
          :timer.sleep(3000)
          get_transaction_by_hash(hash, json_rpc_named_arguments, retries_left)
        end
    end
  end

  def decode_data("0x", types) do
    for _ <- types, do: nil
  end

  def decode_data("0x" <> encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  def decode_data(%Data{} = data, types) do
    data
    |> Data.to_string()
    |> decode_data(types)
  end

  def get_logs_range_size do
    @eth_get_logs_range_size
  end

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

  def parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  def parse_integer(_integer_string), do: nil
end
