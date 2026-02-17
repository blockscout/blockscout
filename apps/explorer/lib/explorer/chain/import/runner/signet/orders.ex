defmodule Explorer.Chain.Import.Runner.Signet.Orders do
  @moduledoc """
    Bulk imports of Explorer.Chain.Signet.Order.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Signet.Order
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Order.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Order

  @impl Import.Runner
  def option_key, do: :signet_orders

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

    Multi.run(multi, Order.insert_result_key(), fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :signet_orders,
        :signet_orders
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Order.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Order ShareLocks order (see docs: sharelock.md)
    # Sort by composite primary key: transaction_hash, then log_index
    ordered_changes_list =
      Enum.sort_by(changes_list, fn change ->
        {change.transaction_hash, change.log_index}
      end)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:transaction_hash, :log_index],
        on_conflict: on_conflict,
        for: Order,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      o in Order,
      update: [
        set: [
          # Don't update primary key fields (transaction_hash, log_index)
          deadline: fragment("COALESCE(EXCLUDED.deadline, ?)", o.deadline),
          block_number: fragment("COALESCE(EXCLUDED.block_number, ?)", o.block_number),
          inputs_json: fragment("COALESCE(EXCLUDED.inputs_json, ?)", o.inputs_json),
          outputs_json: fragment("COALESCE(EXCLUDED.outputs_json, ?)", o.outputs_json),
          sweep_recipient: fragment("COALESCE(EXCLUDED.sweep_recipient, ?)", o.sweep_recipient),
          sweep_token: fragment("COALESCE(EXCLUDED.sweep_token, ?)", o.sweep_token),
          sweep_amount: fragment("COALESCE(EXCLUDED.sweep_amount, ?)", o.sweep_amount),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", o.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", o.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.deadline, EXCLUDED.block_number, EXCLUDED.sweep_recipient, EXCLUDED.sweep_token, EXCLUDED.sweep_amount) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          o.deadline,
          o.block_number,
          o.sweep_recipient,
          o.sweep_token,
          o.sweep_amount
        )
    )
  end
end
