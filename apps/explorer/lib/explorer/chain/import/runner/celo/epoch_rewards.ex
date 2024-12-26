defmodule Explorer.Chain.Import.Runner.Celo.EpochRewards do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Celo.EpochReward.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Celo.{EpochReward, PendingEpochBlockOperation}
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [EpochReward.t()]

  @impl Import.Runner
  def ecto_schema_module, do: EpochReward

  @impl Import.Runner
  def option_key, do: :celo_epoch_rewards

  @impl Import.Runner
  @spec imported_table_row() :: %{:value_description => binary(), :value_type => binary()}
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  @spec run(Multi.t(), list(), map()) :: Multi.t()
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    multi
    |> Multi.run(:acquire_pending_epoch_block_operations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> acquire_pending_epoch_block_operations(repo, changes_list) end,
        :block_pending,
        :celo_epoch_rewards,
        :acquire_pending_epoch_block_operations
      )
    end)
    |> Multi.run(:insert_celo_epoch_rewards, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :celo_epoch_rewards,
        :celo_epoch_rewards
      )
    end)
    |> Multi.run(
      :delete_pending_epoch_block_operations,
      fn repo,
         %{
           acquire_pending_epoch_block_operations: pending_block_hashes
         } ->
        Instrumenter.block_import_stage_runner(
          fn -> delete_pending_epoch_block_operations(repo, pending_block_hashes) end,
          :block_pending,
          :celo_epoch_rewards,
          :delete_pending_epoch_block_operations
        )
      end
    )
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [EpochReward.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Celo.EpochReward ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.block_hash)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: EpochReward,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :block_hash,
        on_conflict: :replace_all
      )

    {:ok, inserted}
  end

  def acquire_pending_epoch_block_operations(repo, changes_list) do
    block_hashes = Enum.map(changes_list, & &1.block_hash)

    query =
      from(
        pending_ops in PendingEpochBlockOperation,
        where: pending_ops.block_hash in ^block_hashes,
        select: pending_ops.block_hash,
        # Enforce PendingBlockOperation ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: pending_ops.block_hash],
        lock: "FOR UPDATE"
      )

    {:ok, repo.all(query)}
  end

  def delete_pending_epoch_block_operations(repo, block_hashes) do
    delete_query =
      from(
        pending_ops in PendingEpochBlockOperation,
        where: pending_ops.block_hash in ^block_hashes
      )

    try do
      # ShareLocks order already enforced by
      # `acquire_pending_epoch_block_operations` (see docs: sharelocks.md)
      {_count, deleted} = repo.delete_all(delete_query, [])

      {:ok, deleted}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, pending_hashes: block_hashes}}
    end
  end
end
