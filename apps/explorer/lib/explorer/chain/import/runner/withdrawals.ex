defmodule Explorer.Chain.Import.Runner.Withdrawals do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Withdrawal.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, Withdrawal}
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Withdrawal.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Withdrawal

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

    Multi.run(multi, :withdrawals, fn repo, _ ->
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

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Withdrawal.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Withdrawal ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.index)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:index],
        on_conflict: on_conflict,
        for: Withdrawal,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      withdrawal in Withdrawal,
      update: [
        set: [
          validator_index: fragment("EXCLUDED.validator_index"),
          amount: fragment("EXCLUDED.amount"),
          address_hash: fragment("EXCLUDED.address_hash"),
          block_hash: fragment("EXCLUDED.block_hash"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", withdrawal.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", withdrawal.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.validator_index, EXCLUDED.amount, EXCLUDED.address_hash, EXCLUDED.block_hash) IS DISTINCT FROM (?, ?, ?, ?)",
          withdrawal.validator_index,
          withdrawal.amount,
          withdrawal.address_hash,
          withdrawal.block_hash
        )
    )
  end
end
