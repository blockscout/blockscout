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

  Rules are evaluated based on the target version. If multiple rules match,
  the most specific one (with the highest `:since` version) is applied.

  If no rule matches the target version, the upgrade is allowed by default.
  """

  alias Explorer.Application.Constants
  alias Explorer.Chain.Block
  alias Explorer.Migrator.HeavyDbIndexOperation.UpdateInternalTransactionsPrimaryKey
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  @upgrade_rules [
    %{
      since: "11.0.0",
      min_from: "10.2.3",
      required_completed_migrations: [UpdateInternalTransactionsPrimaryKey.migration_name()]
    }
  ]

  def validate_current_upgrade do
    previous_version = Constants.get_previous_backend_version()
    current_version = Constants.get_current_backend_version()

    validate_upgrade(previous_version, current_version)
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
    |> Enum.max_by(&Version.parse!(&1.since), Version)
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
      Enum.flat_map(migration_names, fn migration_name ->
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

  defp raise_wrong_version(from_version, to_version, min_from) do
    raise "Upgrade to #{to_version} is allowed only from version #{min_from} and higher. Current previous version: #{from_version || "(empty)"}"
  end

  defp raise_not_completed_migrations(to_version, not_completed) do
    raise "Upgrade to #{to_version} is not allowed because required migrations are not completed: #{Enum.join(not_completed, ", ")}"
  end
end
