defmodule Indexer.Transform.Celo.L2Epochs do
  @moduledoc """
  Transformer for Celo L2 epoch data from blockchain logs.

  This module processes logs from the Celo EpochManager contract to extract
  epoch information for post-migration blocks (L2 epochs). It identifies epoch
  processing start and end events by filtering logs based on their topics and
  the contract address.

  This information is essential for tracking Celo's epoch structure after the L2
  migration, which no longer follows a simple deterministic formula.
  """

  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    epoch_manager_contract_address: [
      :explorer,
      [:celo, :epoch_manager_contract_address]
    ]

  import Explorer.Helper, only: [decode_data: 2]

  alias Explorer.Chain.Celo.Helper

  # Events from the EpochManager contract
  @epoch_processing_started_topic "0xae58a33f8b8d696bcbaca9fa29d9fdc336c140e982196c2580db3d46f3e6d4b6"
  @epoch_processing_ended_topic "0xc8e58d8e6979dd5e68bad79d4a4368a1091f6feb2323e612539b1b84e0663a8f"

  @spec parse([map()]) :: [map()]
  def parse(logs) do
    if chain_type() == :celo do
      do_parse(logs)
    else
      []
    end
  end

  defp do_parse(logs) do
    logs
    |> Enum.filter(
      &(not Helper.pre_migration_block_number?(&1.block_number) and
          &1.address_hash == epoch_manager_contract_address() |> String.downcase() and
          &1.first_topic in [
            @epoch_processing_started_topic,
            @epoch_processing_ended_topic
          ])
    )
    |> Enum.reduce(%{}, fn log, epochs_acc ->
      # Extract epoch number from the log
      [epoch_number] = decode_data(log.second_topic, [{:uint, 256}])

      current_epoch = Map.get(epochs_acc, epoch_number, %{number: epoch_number})

      updated_epoch =
        case log.first_topic do
          @epoch_processing_started_topic ->
            Map.put(current_epoch, :start_processing_block_hash, log.block_hash)

          @epoch_processing_ended_topic ->
            Map.put(current_epoch, :end_processing_block_hash, log.block_hash)
        end

      Map.put(epochs_acc, epoch_number, updated_epoch)
    end)
    |> Map.values()
  end
end
