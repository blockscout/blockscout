defmodule Explorer.Chain.Import.Runner.Celo.ValidatorGroupVotes do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Celo.ValidatorGroupVote.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Celo.ValidatorGroupVote
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [ValidatorGroupVote.t()]

  @impl Import.Runner
  def ecto_schema_module, do: ValidatorGroupVote

  @impl Import.Runner
  def option_key, do: :celo_validator_group_votes

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

    Multi.run(multi, :insert_celo_validator_group_votes, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :celo_validator_group_votes,
        :celo_validator_group_votes
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [ValidatorGroupVote.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Celo.Epoch.ValidatorGroupVote ShareLocks order (see docs: sharelock.md)
    ordered_changes_list =
      Enum.sort_by(
        changes_list,
        &{
          &1.transaction_hash,
          &1.account_address_hash,
          &1.group_address_hash
        }
      )

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: ValidatorGroupVote,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [
          :transaction_hash,
          :account_address_hash,
          :group_address_hash
        ],
        on_conflict: :replace_all
      )

    {:ok, inserted}
  end
end
