defmodule Explorer.Chain.Import.Runner.Beacon.BlobTransactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Beacon.BlobTransaction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Beacon.BlobTransaction
  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Hash, Import}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Hash.Full.t()]

  @impl Import.Runner
  def ecto_schema_module, do: BlobTransaction

  @impl Import.Runner
  def option_key, do: :beacon_blob_transactions

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

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi
    |> Multi.run(:beacon_blob_transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :beacon_blob_transactions,
        :beacon_blob_transactions
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Hash.t()]}
  defp insert(
         repo,
         changes_list,
         %{
           timeout: timeout,
           timestamps: timestamps
         } = options
       )
       when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: BlobTransaction,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      blob_transaction in BlobTransaction,
      update: [
        set: [
          max_fee_per_blob_gas: fragment("EXCLUDED.max_fee_per_blob_gas"),
          blob_versioned_hashes: fragment("EXCLUDED.blob_versioned_hashes"),
          blob_gas_used: fragment("EXCLUDED.blob_gas_used"),
          blob_gas_price: fragment("EXCLUDED.blob_gas_price"),
          # Don't update `hash` as it is part of the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", blob_transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", blob_transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.max_fee_per_blob_gas, EXCLUDED.blob_versioned_hashes, EXCLUDED.blob_gas_used, EXCLUDED.blob_gas_price) IS DISTINCT FROM (?, ?, ?, ?)",
          blob_transaction.max_fee_per_blob_gas,
          blob_transaction.blob_versioned_hashes,
          blob_transaction.blob_gas_used,
          blob_transaction.blob_gas_price
        )
    )
  end
end
