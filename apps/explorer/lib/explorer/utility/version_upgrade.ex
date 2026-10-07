# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.VersionUpgrade do
  @moduledoc """
  Provides validation logic for application version upgrades.

  This module ensures that upgrading from one version of the application
  to another is allowed according to a set of predefined rules. It is
  designed to prevent unsafe upgrades that could lead to inconsistent
  data or incomplete migrations.

  ## Upgrade Rules

  Upgrade rules are defined as a list of maps in `@upgrade_rules`. Each rule
  applies to a range of target versions and has the following structure:

    * `:since` — the minimum target version (inclusive) for which the rule applies
    * `:min_from` — the minimum allowed source version (inclusive)
    * `:required_completed_migrations` — a list of migration names that must
      have status `"completed"` before the upgrade is allowed

  Each entry of `:required_completed_migrations` is either:

    * a migration name — the migration is required on every chain type, or
    * a `{migration_name, chain_types}` tuple — the migration is required only
      when the current chain type is one of `chain_types`. This is meant for
      migrations that are started only on some chain types (see
      `Explorer.Application`), since on the other chain types they never reach
      the `"completed"` status.

  Rules are evaluated based on the target version. If multiple rules match,
  the most specific one (with the highest `:since` version) is applied.

  If no rule matches the target version, the upgrade is allowed by default.

  ## Validation points

  The upgrade is validated twice:

    * by `Explorer.ReleaseTasks` before the database migrations are applied (see
      `validate_before_migrations/0`), so that a rejected upgrade leaves the
      database untouched;
    * on the application start, which also covers the migrations applied in
      another way (e.g. `mix ecto.migrate`) and guards the background migrations
      started by `Explorer.Application`.

  Since the first validation runs against the database schema of the previous
  version, the queries of this module must touch only the tables and columns
  which exist in the schema of the `:min_from` versions. For the same reason,
  the migrations of a release must not change the statuses of the migrations
  required by its rule: the validation before the migrations would pass, while
  the one on the application start would fail on the already migrated database.
  """

  use GenServer

  use Utils.RuntimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Application.Constants
  alias Explorer.Chain.Block
  alias Explorer.Migrator.HeavyDbIndexOperation.UpdateInternalTransactionsPrimaryKey

  alias Explorer.Migrator.{
    FillInternalTransactionsAddressIds,
    MigrationStatus,
    SanitizeDuplicatedLogIndexLogs
  }

  alias Explorer.Repo

  @upgrade_rules [
    %{
      since: "11.0.0",
      min_from: "10.2.3",
      required_completed_migrations: [UpdateInternalTransactionsPrimaryKey.migration_name()]
    },
    %{
      since: "12.0.0",
      min_from: "11.0.2",
      required_completed_migrations: [
        FillInternalTransactionsAddressIds.migration_name(),
        {SanitizeDuplicatedLogIndexLogs.migration_name(), [:rsk, :filecoin]}
      ]
    }
  ]

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    validate_current_upgrade()
    :ignore
  end

  def validate_current_upgrade do
    validate_upgrade(Constants.get_current_backend_version(), current_version())
  end

  @doc """
  Validates the upgrade to the current version before the database migrations
  are applied, i.e. against the database schema of the previously running
  version. Called by `Explorer.ReleaseTasks`.

  Does nothing if the validation is disabled or the database is fresh.
  """
  @spec validate_before_migrations() :: :ok
  def validate_before_migrations do
    cond do
      not enabled?() ->
        :ok

      not table_exists?("blocks") ->
        :ok

      # the database of a version released before the `constants` table was added
      not table_exists?("constants") ->
        validate_upgrade(nil, current_version())

      true ->
        validate_current_upgrade()
    end
  end

  def validate_upgrade(nil, to_version) do
    case find_applicable_rule(to_version) do
      nil ->
        :ok

      %{min_from: min_from} ->
        if Repo.exists?(Block) do
          raise_wrong_version(nil, to_version, min_from)
        else
          :ok
        end
    end
  end

  def validate_upgrade(from_version, to_version) do
    case find_applicable_rule(to_version) do
      nil ->
        :ok

      rule ->
        validate_min_from!(from_version, to_version, rule)
        validate_required_migrations!(to_version, rule)
    end
  end

  defp find_applicable_rule(to_version) do
    @upgrade_rules
    |> Enum.filter(fn %{since: since_version} ->
      Version.compare(to_version, since_version) in [:eq, :gt]
    end)
    |> Enum.max_by(&Version.parse!(&1.since), Version, fn -> nil end)
  end

  defp validate_min_from!(from_version, to_version, %{min_from: min_from}) do
    if Version.compare(from_version, min_from) in [:eq, :gt] do
      :ok
    else
      raise_wrong_version(from_version, to_version, min_from)
    end
  end

  defp validate_required_migrations!(_to_version, %{required_completed_migrations: []}), do: :ok

  defp validate_required_migrations!(to_version, %{required_completed_migrations: migration_names}) do
    not_completed =
      migration_names
      |> Enum.filter(&required_on_current_chain_type?/1)
      |> Enum.map(&migration_name/1)
      |> Enum.flat_map(fn migration_name ->
        status = MigrationStatus.get_status(migration_name)

        if status == "completed" do
          []
        else
          ["#{migration_name} (status: #{inspect(status)})"]
        end
      end)

    if not_completed == [] do
      :ok
    else
      raise_not_completed_migrations(to_version, not_completed)
    end
  end

  defp validate_required_migrations!(_to_version, _rule), do: :ok

  defp required_on_current_chain_type?({_migration_name, chain_types}), do: chain_type() in chain_types
  defp required_on_current_chain_type?(_migration_name), do: true

  defp migration_name({migration_name, _chain_types}), do: migration_name
  defp migration_name(migration_name), do: migration_name

  defp current_version, do: to_string(Application.spec(:explorer, :vsn))

  defp enabled?, do: Application.get_env(:explorer, __MODULE__, [])[:enabled] == true

  defp table_exists?(table_name) do
    %{rows: [[exists?]]} = Repo.query!("SELECT to_regclass($1) IS NOT NULL", [table_name])
    exists?
  end

  defp raise_wrong_version(from_version, to_version, min_from) do
    raise "Upgrade to #{to_version} is allowed only from version #{min_from} and higher. Current previous version: #{from_version || "(empty)"}"
  end

  defp raise_not_completed_migrations(to_version, not_completed) do
    raise "Upgrade to #{to_version} is not allowed because required migrations are not completed: #{Enum.join(not_completed, ", ")}"
  end
end
