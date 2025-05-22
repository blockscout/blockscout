defmodule Explorer.Chain.Celo.Reader.EpochManager do
  @moduledoc """
  Functions for interacting with the Celo Epoch Manager contract.
  """

  use Utils.RuntimeEnvHelper,
    epoch_manager_contract_address_hash: [
      :explorer,
      [:celo, :epoch_manager_contract_address]
    ]

  @get_first_block_at_epoch_abi [
    %{
      "inputs" => [%{"type" => "uint256"}],
      "name" => "getFirstBlockAtEpoch",
      "outputs" => [%{"type" => "uint256"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @get_last_block_at_epoch_abi [
    %{
      "inputs" => [%{"type" => "uint256"}],
      "name" => "getLastBlockAtEpoch",
      "outputs" => [%{"type" => "uint256"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  alias Explorer.Helper
  alias Explorer.SmartContract.Reader

  @doc """
  Retrieves the first block number in a given epoch.

  ## Parameters

    * `block_number` - The epoch number to retrieve epoch for.

  ## Returns

    * `{:ok, number}` - The first block number in the epoch.
    * `:error` - If the request fails.
  """
  @spec fetch_first_block_at_epoch(non_neg_integer()) ::
          {:ok, non_neg_integer()} | :error
  def fetch_first_block_at_epoch(block_number) do
    method_id = Helper.abi_to_method_id(@get_first_block_at_epoch_abi)

    epoch_manager_contract_address_hash()
    |> Reader.query_contract(
      @get_first_block_at_epoch_abi,
      %{method_id => [block_number]},
      false
    )
    |> case do
      %{^method_id => {:ok, [number]}} -> {:ok, number}
      _ -> :error
    end
  end

  @doc """
  Retrieves the last block number in a given epoch.

  ## Parameters

    * `block_number` - The epoch number to retrieve epoch for.

  ## Returns

    * `{:ok, number}` - The last block number in the epoch.
    * `:error` - If the request fails.
  """
  @spec fetch_last_block_at_epoch(non_neg_integer()) ::
          {:ok, non_neg_integer()} | :error
  def fetch_last_block_at_epoch(block_number) do
    method_id = Helper.abi_to_method_id(@get_last_block_at_epoch_abi)

    epoch_manager_contract_address_hash()
    |> Reader.query_contract(
      @get_last_block_at_epoch_abi,
      %{method_id => [block_number]},
      false
    )
    |> case do
      %{^method_id => {:ok, [number]}} -> {:ok, number}
      _ -> :error
    end
  end
end
