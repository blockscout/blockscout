defmodule Explorer.Chain.Import.Runner.TokenTransfers do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.TokenTransfer.t/0`.
  """

  require Ecto.Query
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Accounts.Notify.Notifier
  alias Explorer.Chain.{Import, TokenTransfer}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TokenTransfer.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TokenTransfer

  @impl Import.Runner
  def option_key, do: :token_transfers

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

    Multi.run(multi, :token_transfers, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [TokenTransfer.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce TokenTransfer ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.block_hash, &1.log_index})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:transaction_hash, :log_index, :block_hash],
        on_conflict: on_conflict,
        for: TokenTransfer,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    try do
      Notifier.notify(inserted)
    rescue
      err ->
        Logger.info("--- Notifier error", fetcher: :account)
        Logger.info(err, fetcher: :account)
    end

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      token_transfer in TokenTransfer,
      update: [
        set: [
          # Don't update `transaction_hash` as it is part of the composite primary key and used for the conflict target
          # Don't update `log_index` as it is part of the composite primary key and used for the conflict target
          amount: fragment("EXCLUDED.amount"),
          from_address_hash: fragment("EXCLUDED.from_address_hash"),
          to_address_hash: fragment("EXCLUDED.to_address_hash"),
          token_contract_address_hash: fragment("EXCLUDED.token_contract_address_hash"),
          token_id: fragment("EXCLUDED.token_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token_transfer.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_transfer.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.amount, EXCLUDED.from_address_hash, EXCLUDED.to_address_hash, EXCLUDED.token_contract_address_hash, EXCLUDED.token_id) IS DISTINCT FROM (?, ? ,? , ?, ?)",
          token_transfer.amount,
          token_transfer.from_address_hash,
          token_transfer.to_address_hash,
          token_transfer.token_contract_address_hash,
          token_transfer.token_id
        )
    )
  end
end
