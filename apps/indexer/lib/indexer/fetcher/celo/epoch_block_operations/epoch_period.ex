defmodule Indexer.Fetcher.Celo.EpochBlockOperations.EpochPeriod do
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

  import Indexer.Fetcher.Celo.Helper, only: [abi_to_method_id: 1]

  alias Indexer.Helper, as: IndexerHelper

  @repeated_request_max_retries 3

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

  @spec fetch(non_neg_integer()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}}
          | {:error, any()}
  def fetch(number) do
    with {:ok, first_block_number} <- read_contract(number, @get_first_block_at_epoch_abi),
         {:ok, last_block_number} <- read_contract(number, @get_last_block_at_epoch_abi) do
      {:ok,
       {
         first_block_number,
         last_block_number
       }}
    else
      {:error, errors} = error ->
        Logger.error("Failed to fetch epoch period: #{inspect(errors)}")
        error
    end
  end

  @spec read_contract(integer(), list()) ::
          {:ok, integer()} | {:error, any()}
  defp read_contract(number, abi) do
    [
      %{
        contract_address: epoch_manager_contract_address_hash(),
        method_id: abi_to_method_id(abi),
        args: [number]
      }
    ]
    |> IndexerHelper.read_contracts_with_retries(
      abi,
      json_rpc_named_arguments(),
      @repeated_request_max_retries
    )
    |> case do
      {[ok: [value]], []} ->
        {:ok, value}

      {_, errors} ->
        {:error, errors}
    end
  end
end
