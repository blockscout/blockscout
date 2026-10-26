# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Helper do
  @moduledoc """
  Provides utility functions for the chain import runners.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Block

  @doc """
  Executes the import function if the configured chain type matches the
  specified `chain_type`.
  """
  @spec chain_type_dependent_import(
          Ecto.Multi.t(),
          chain_type :: atom(),
          (Ecto.Multi.t() -> Ecto.Multi.t())
        ) :: Ecto.Multi.t()
  def chain_type_dependent_import(multi, chain_type, multi_run) do
    if Application.get_env(:explorer, :chain_type) == chain_type do
      multi_run.(multi)
    else
      multi
    end
  end

  @doc """
  Executes the import function if the configured chain identity matches the
  specified `chain_identity`.
  """
  @spec chain_identity_dependent_import(
          Ecto.Multi.t(),
          chain_identity :: atom() | tuple(),
          (Ecto.Multi.t() -> Ecto.Multi.t())
        ) :: Ecto.Multi.t()
  def chain_identity_dependent_import(multi, chain_identity, multi_run) do
    if Application.get_env(:explorer, :chain_identity) == chain_identity do
      multi_run.(multi)
    else
      multi
    end
  end

  @doc """
  Drops the changes that belong to blocks which are not consensus anymore.

  Data that references a block, such as logs and token transfers, is imported in a later
  stage than the block itself, in a separate transaction. A concurrent import can make the
  block non-consensus in between, and the consensus loss handling of
  `Explorer.Chain.Import.Runner.Blocks` (e.g. the deletion of the block logs) does not see
  the data that is not committed yet. So the blocks are locked here with `FOR SHARE`, which
  conflicts with the `FOR NO KEY UPDATE` lock taken on the consensus loss. Either the
  consensus loss commits first, and then the changes of the lost blocks are dropped here, or
  it waits for this transaction and then handles the committed data.

  Must be called in the import transaction before inserting the changes. The changes without
  a block hash and the changes of the blocks that are not stored are kept.

  ## Parameters
  - `repo`: the repo of the import transaction.
  - `changes_list`: the changes to filter, a change belongs to the block with its `block_hash`.
  - `options`: the runner options with the `timeout` for the lock query.
  - `entity`: what the changes are, used in the log message.

  ## Returns
  - The changes that do not belong to non-consensus blocks.
  """
  @spec reject_changes_of_non_consensus_blocks(
          Ecto.Repo.t(),
          [map()],
          %{required(:timeout) => timeout(), optional(atom()) => any()},
          String.t()
        ) :: [map()]
  def reject_changes_of_non_consensus_blocks(repo, changes_list, %{timeout: timeout}, entity) do
    block_hashes =
      changes_list
      |> Enum.map(&Map.get(&1, :block_hash))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if block_hashes == [] do
      changes_list
    else
      query =
        from(
          block in Block,
          where: block.hash in ^block_hashes,
          select: {block.hash, block.consensus},
          # Enforce Block ShareLocks order (see docs: sharelocks.md)
          order_by: [asc: block.hash],
          lock: "FOR SHARE"
        )

      non_consensus_block_hashes = for {hash, false} <- repo.all(query, timeout: timeout), into: MapSet.new(), do: hash

      reject_changes_of_blocks(changes_list, non_consensus_block_hashes, entity)
    end
  end

  defp reject_changes_of_blocks(changes_list, block_hashes, entity) do
    if Enum.empty?(block_hashes) do
      changes_list
    else
      {rejected_changes, kept_changes} =
        Enum.split_with(changes_list, &MapSet.member?(block_hashes, Map.get(&1, :block_hash)))

      Logger.info(fn ->
        block_numbers = rejected_changes |> Enum.map(&Map.get(&1, :block_number)) |> Enum.uniq() |> Enum.sort()

        [
          "Skipped ",
          to_string(length(rejected_changes)),
          " ",
          entity,
          " of non-consensus blocks ",
          inspect(block_numbers)
        ]
      end)

      kept_changes
    end
  end
end
