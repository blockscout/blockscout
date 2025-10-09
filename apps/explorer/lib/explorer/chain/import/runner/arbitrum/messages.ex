defmodule Explorer.Chain.Import.Runner.Arbitrum.Messages do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.Message.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.Message, as: CrosslevelMessage
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CrosslevelMessage.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CrosslevelMessage

  @impl Import.Runner
  def option_key, do: :arbitrum_messages

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

    Multi.run(multi, :insert_arbitrum_messages, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_messages,
        :arbitrum_messages
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [CrosslevelMessage.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Message ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.direction, &1.message_id})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:direction, :message_id],
        on_conflict: on_conflict,
        for: CrosslevelMessage,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      op in CrosslevelMessage,
      update: [
        set: [
          # Don't update `direction` as it is part of the composite primary key and used for the conflict target
          # Don't update `message_id` as it is part of the composite primary key and used for the conflict target
          originator_address: fragment("COALESCE(EXCLUDED.originator_address, ?)", op.originator_address),
          originating_transaction_hash:
            fragment("COALESCE(EXCLUDED.originating_transaction_hash, ?)", op.originating_transaction_hash),
          origination_timestamp: fragment("COALESCE(EXCLUDED.origination_timestamp, ?)", op.origination_timestamp),
          originating_transaction_block_number:
            fragment(
              "COALESCE(EXCLUDED.originating_transaction_block_number, ?)",
              op.originating_transaction_block_number
            ),
          completion_transaction_hash:
            fragment("COALESCE(EXCLUDED.completion_transaction_hash, ?)", op.completion_transaction_hash),
          status: fragment("GREATEST(?, EXCLUDED.status)", op.status),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", op.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", op.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.originator_address, EXCLUDED.originating_transaction_hash, EXCLUDED.origination_timestamp, EXCLUDED.originating_transaction_block_number, EXCLUDED.completion_transaction_hash, EXCLUDED.status) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          op.originator_address,
          op.originating_transaction_hash,
          op.origination_timestamp,
          op.originating_transaction_block_number,
          op.completion_transaction_hash,
          op.status
        )
    )
  end
end
