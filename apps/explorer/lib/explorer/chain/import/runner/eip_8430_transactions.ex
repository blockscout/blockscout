# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.EIP8430Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.EIP8430Transaction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{EIP8430Transaction, Import}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [EIP8430Transaction.t()]

  @impl Import.Runner
  def ecto_schema_module, do: EIP8430Transaction

  @impl Import.Runner
  def option_key, do: :eip_8430_transactions

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

    Multi.run(multi, :eip_8430_transactions, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :eip_8430_transactions,
        :eip_8430_transactions
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
          {:ok, [EIP8430Transaction.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce EIP8430Transaction ShareLocks order (see docs: sharelocks.md).
    # A node can return the same transaction twice in one block. Two rows with the same key in
    # one `INSERT ... ON CONFLICT DO UPDATE` make Postgres stop with an error.
    ordered_changes_list =
      changes_list
      |> Enum.sort_by(& &1.transaction_hash)
      |> Enum.uniq_by(& &1.transaction_hash)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: EIP8430Transaction,
        on_conflict: on_conflict,
        conflict_target: [:transaction_hash],
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      eip_8430_transaction in EIP8430Transaction,
      update: [
        set: [
          has_named_sender: fragment("EXCLUDED.has_named_sender"),
          nonce_key: fragment("EXCLUDED.nonce_key"),
          valid_after: fragment("EXCLUDED.valid_after"),
          valid_before: fragment("EXCLUDED.valid_before"),
          metadata: fragment("EXCLUDED.metadata"),
          payer_type: fragment("EXCLUDED.payer_type"),
          payer: fragment("EXCLUDED.payer"),
          sender_auth: fragment("EXCLUDED.sender_auth"),
          payer_auth: fragment("EXCLUDED.payer_auth"),
          account_changes: fragment("EXCLUDED.account_changes"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", eip_8430_transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", eip_8430_transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.has_named_sender, EXCLUDED.nonce_key, EXCLUDED.valid_after, EXCLUDED.valid_before, EXCLUDED.metadata, EXCLUDED.payer_type, EXCLUDED.payer, EXCLUDED.sender_auth, EXCLUDED.payer_auth, EXCLUDED.account_changes) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          eip_8430_transaction.has_named_sender,
          eip_8430_transaction.nonce_key,
          eip_8430_transaction.valid_after,
          eip_8430_transaction.valid_before,
          eip_8430_transaction.metadata,
          eip_8430_transaction.payer_type,
          eip_8430_transaction.payer,
          eip_8430_transaction.sender_auth,
          eip_8430_transaction.payer_auth,
          eip_8430_transaction.account_changes
        )
    )
  end
end
