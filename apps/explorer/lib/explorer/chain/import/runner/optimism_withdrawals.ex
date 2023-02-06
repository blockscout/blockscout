defmodule Explorer.Chain.Import.Runner.OptimismWithdrawals do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.OptimismWithdrawal.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, OptimismWithdrawal}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [OptimismWithdrawal.t()]

  @impl Import.Runner
  def ecto_schema_module, do: OptimismWithdrawal

  @impl Import.Runner
  def option_key, do: :withdrawals

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_withdrawals, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :withdrawals,
        :withdrawals
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [OptimismWithdrawal.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce OptimismWithdrawal ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.msg_nonce)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: OptimismWithdrawal,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :msg_nonce,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      withdrawal in OptimismWithdrawal,
      update: [
        set: [
          # don't update `msg_nonce` as it is a primary key and used for the conflict target
          withdrawal_hash: fragment("EXCLUDED.withdrawal_hash"),
          l2_tx_hash: fragment("EXCLUDED.l2_tx_hash"),
          l2_block_number: fragment("EXCLUDED.l2_block_number"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", withdrawal.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", withdrawal.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.withdrawal_hash, EXCLUDED.l2_tx_hash, EXCLUDED.l2_block_number) IS DISTINCT FROM (?, ?, ?)",
          withdrawal.withdrawal_hash,
          withdrawal.l2_tx_hash,
          withdrawal.l2_block_number
        )
    )
  end
end
