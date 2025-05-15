defmodule Indexer.Fetcher.Optimism.Interop.Helper do
  @moduledoc """
    Auxiliary common functions for OP Interop indexers.
  """

  require Logger

  @doc """
    Outputs an error message about `eth_chainId` JSON-RPC request was failed.

    ## Returns
    - :ok
  """
  @spec log_cant_get_chain_id_from_rpc() :: :ok
  def log_cant_get_chain_id_from_rpc do
    Logger.error("Cannot get chain ID from RPC.")
  end

  @doc """
    Outputs an error message about `eth_getTransactionByHash` JSON-RPC request was failed.

    ## Parameters
    - `error_data`: Contains error data returned by RPC node.

    ## Returns
    - :ok
  """
  @spec log_cant_get_last_transaction_from_rpc(any()) :: :ok
  def log_cant_get_last_transaction_from_rpc(error_data) do
    Logger.error("Cannot get last transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")
  end

  @doc """
    Outputs last known block number (got from DB) and latest block number (got from RPC) for debugging purposes.

    ## Parameters
    - `last_block_number`: The last known block number from database.
    - `last_block_number`: The latest block number from RPC node.

    ## Returns
    - :ok
  """
  @spec log_last_block_numbers(non_neg_integer(), non_neg_integer()) :: :ok
  def log_last_block_numbers(last_block_number, latest_block_number) do
    Logger.info("last_block_number = #{last_block_number}")
    Logger.info("latest_block_number = #{latest_block_number}")
  end
end
