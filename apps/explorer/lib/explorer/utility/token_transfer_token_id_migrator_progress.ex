defmodule Explorer.Utility.TokenTransferTokenIdMigratorProgress do
  @moduledoc """
  Module is responsible for keeping the current progress of TokenTransfer token_id migration.
  Full algorithm is in the 'Indexer.Fetcher.TokenTransferTokenIdMigration.Supervisor' module doc.
  """
  use Explorer.Schema

  require Logger

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Repo

  schema "token_transfer_token_id_migrator_progress" do
    field(:last_processed_block_number, :integer)

    timestamps()
  end

  @doc false
  def changeset(progress \\ %__MODULE__{}, params) do
    cast(progress, params, [:last_processed_block_number])
  end

  def get_current_progress do
    Repo.one(
      from(
        p in __MODULE__,
        order_by: [desc: p.updated_at],
        limit: 1
      )
    )
  end

  def get_last_processed_block_number do
    case get_current_progress() do
      nil ->
        latest_processed_block_number = BlockNumber.get_max() + 1
        update_last_processed_block_number(latest_processed_block_number)
        latest_processed_block_number

      %{last_processed_block_number: block_number} ->
        block_number
    end
  end

  def update_last_processed_block_number(block_number) do
    case get_current_progress() do
      nil ->
        %{last_processed_block_number: block_number}
        |> changeset()
        |> Repo.insert()

      progress ->
        if progress.last_processed_block_number < block_number do
          Logger.error(
            "TokenTransferTokenIdMigratorProgress new block_number is above the last one. Last: #{progress.last_processed_block_number}, new: #{block_number}"
          )

          {:error, :invalid_block_number}
        else
          progress
          |> changeset(%{last_processed_block_number: block_number})
          |> Repo.update()
        end
    end
  end
end
