defmodule Indexer.Fetcher.Celo.EpochBlockOperations.EpochNumberByBlockNumber do
  @moduledoc """
  Fetches the start and end block numbers for epochs post L2 migration.
  """
  require Logger

  use Utils.RuntimeEnvHelper,
    epoch_manager_contract_address_hash: [
      :explorer,
      [:celo, :epoch_manager_contract_address]
    ],
    json_rpc_named_arguments: [:indexer, :json_rpc_named_arguments]

  alias Explorer.Chain.Celo.Epoch
  alias Indexer.Fetcher.Celo.Helper, as: CeloHelper
  alias Indexer.Helper, as: IndexerHelper

  @repeated_request_max_retries 3

  @get_epoch_by_block_number_abi [
    %{
      "name" => "getEpochNumberOfBlock",
      "type" => "function",
      "stateMutability" => "view",
      "inputs" => [%{"type" => "uint256"}],
      "outputs" => [%{"type" => "uint256"}]
    }
  ]

  @spec fetch(non_neg_integer()) :: {:ok, Epoch.t()} | {:error, any()}
  def fetch(block_number) do
    [
      %{
        contract_address: epoch_manager_contract_address_hash(),
        method_id: CeloHelper.abi_to_method_id(@get_epoch_by_block_number_abi),
        args: [block_number]
      }
    ]
    |> IndexerHelper.read_contracts_with_retries(
      @get_epoch_by_block_number_abi,
      json_rpc_named_arguments(),
      @repeated_request_max_retries
    )
    |> case do
      {[ok: [number]], []} ->
        {:ok, number}

      {_, errors} ->
        Logger.error("Failed to fetch epoch number by block number #{block_number}: #{inspect(errors)}")
        {:error, errors}
    end
  end
end
