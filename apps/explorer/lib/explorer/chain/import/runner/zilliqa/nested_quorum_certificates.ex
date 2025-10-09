defmodule Explorer.Chain.Import.Runner.Zilliqa.NestedQuorumCertificates do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Zilliqa.NestedQuorumCertificate.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Zilliqa.NestedQuorumCertificate
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [NestedQuorumCertificate.t()]

  @impl Import.Runner
  def ecto_schema_module, do: NestedQuorumCertificate

  @impl Import.Runner
  def option_key, do: :zilliqa_nested_quorum_certificates

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

    Multi.run(multi, :insert_zilliqa_nested_quorum_certificates, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :zilliqa_nested_quorum_certificates,
        :zilliqa_nested_quorum_certificates
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [NestedQuorumCertificate.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = _options) when is_list(changes_list) do
    # Enforce Zilliqa.NestedQuorumCertificate ShareLocks order (see docs: sharelock.md)
    ordered_changes_list =
      Enum.sort_by(
        changes_list,
        &{&1.block_hash, &1.proposed_by_validator_index}
      )

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: NestedQuorumCertificate,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [
          :block_hash,
          :proposed_by_validator_index
        ],
        on_conflict: :nothing
      )

    {:ok, inserted}
  end
end
