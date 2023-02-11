defmodule Indexer.Fetcher.Optimism do
  @moduledoc """
  Contains common functions for Optimism* fetchers.
  """

  require Logger

  import EthereumJSONRPC,
    only: [fetch_block_number_by_tag: 2, json_rpc: 2, integer_to_quantity: 1, request: 1]

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

  def get_logs_range_size do
    @eth_get_logs_range_size
  end
end
