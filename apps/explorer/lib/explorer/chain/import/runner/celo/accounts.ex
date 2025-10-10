defmodule Explorer.Chain.Import.Runner.Celo.Accounts do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Celo.Account.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Celo.Account
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Account.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Account

  @impl Import.Runner
  def option_key, do: :celo_accounts

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
      |> Map.take(~w(timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_celo_accounts, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :address_referencing,
        :celo_accounts,
        :celo_accounts
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Account.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Celo.Epoch.Account ShareLocks order (see docs: sharelock.md)
    ordered_changes_list =
      changes_list
      |> Enum.uniq_by(& &1.address_hash)
      |> Enum.sort_by(& &1.address_hash)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: Account,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :address_hash,
        on_conflict: :replace_all
      )

    {:ok, inserted}
  end
end
