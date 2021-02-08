defmodule Explorer.Chain.Import.Runner.CeloWallets do
  @moduledoc """
  Bulk imports Celo account address to wallet address mappings to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloWallet, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloWallet.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloWallet

  @impl Import.Runner
  def option_key, do: :wallets

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) do
    insert_options = Util.make_insert_options(option_key(), @timeout, options)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi
    |> Multi.run(:acquire_all_items, fn repo, _ ->
      acquire_all_items(repo)
    end)
    |> Multi.run(:insert_wallets, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp acquire_all_items(repo) do
    query =
      from(
        account in CeloWallet,
        # Enforce ShareLocks order (see docs: sharelocks.md)
        order_by: [account.wallet_address_hash, account.account_address_hash],
        lock: "FOR UPDATE"
      )

    accounts = repo.all(query)

    {:ok, accounts}
  end

  @spec insert(Repo.t(), [map()], Util.insert_options()) :: {:ok, [CeloWallet.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.wallet_address_hash, &1.account_address_hash})
      |> Enum.uniq_by(&{&1.wallet_address_hash, &1.account_address_hash})

    Import.insert_changes_list(
      repo,
      uniq_changes_list,
      conflict_target: [:wallet_address_hash, :account_address_hash],
      on_conflict: on_conflict,
      for: CeloWallet,
      returning: [:wallet_address_hash, :account_address_hash],
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      account in CeloWallet,
      update: [
        set: [
          block_number: fragment("EXCLUDED.block_number"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
