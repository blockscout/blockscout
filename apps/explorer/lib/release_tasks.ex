# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.ReleaseTasks do
  @moduledoc """
  Database maintenance entry points for an assembled release, where Mix tasks
  such as `mix ecto.migrate` are not available.

  The functions are meant to be invoked through the release `eval` command,
  which loads the applications without starting them, e.g.:

      bin/blockscout eval "Explorer.ReleaseTasks.create_and_migrate()"

  Every entry point boots the minimal set of applications and the configured
  repos on its own, and shuts the VM down once the work is completed. A failure
  propagates as an exception, so the `eval` command exits with a non-zero code.
  """

  alias Ecto.Migrator
  alias Explorer.Utility.VersionUpgrade

  # the applications a repo needs to connect to the database and to migrate it
  @repo_dependencies ~w(crypto ssl postgrex ecto ecto_sql)a

  # a migration runs on one connection, another one holds the migration lock
  @repo_pool_size 2

  @doc """
  Returns the repos the release tasks operate on.
  """
  @spec repos() :: [Ecto.Repo.t()]
  def repos do
    Application.get_env(:explorer, :ecto_repos)
  end

  @doc """
  Creates the databases of all repos (unless they exist) and migrates them.
  """
  @spec create_and_migrate() :: :ok
  def create_and_migrate do
    with_running_repos(fn ->
      create()
      migrate_repos()
    end)
  end

  @doc """
  Creates the databases of all repos, skipping the ones that already exist.
  """
  @spec create() :: :ok
  def create do
    Enum.each(repos(), &create_db_for/1)
  end

  @doc """
  Applies the pending migrations of all repos.

  The argument is ignored. It is accepted for the callers that pass the command
  line arguments through.
  """
  @spec migrate(term()) :: :ok
  def migrate(_argv \\ []) do
    with_running_repos(&migrate_repos/0)
  end

  @doc """
  Applies the pending migrations of all repos, then evaluates the `seeds.exs`
  script of every repo that ships one.

  The argument is ignored, same as in `migrate/1`.
  """
  @spec seed(term()) :: :ok
  def seed(_argv \\ []) do
    with_running_repos(fn ->
      migrate_repos()
      Enum.each(repos(), &seed_repo/1)
    end)
  end

  # Boots what the repos depend on and the repos themselves, runs `task` and
  # requests the VM shutdown afterwards.
  @spec with_running_repos((-> any())) :: :ok
  defp with_running_repos(task) do
    IO.puts("Booting the repo dependencies: #{Enum.join(@repo_dependencies, ", ")}")

    Enum.each(@repo_dependencies, fn app ->
      {:ok, _started} = Application.ensure_all_started(app)
    end)

    IO.puts("Connecting the repos")
    Enum.each(repos(), & &1.start_link(pool_size: @repo_pool_size))

    task.()

    IO.puts("Release task completed")
    :init.stop()
  end

  defp create_db_for(repo) do
    IO.puts("Create #{inspect(repo)} database if it doesn't exist")

    case repo.__adapter__.storage_up(repo.config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, term} -> {:error, term}
    end
  end

  @spec migrate_repos() :: :ok
  defp migrate_repos do
    # must precede the migrations of all repos: a rejected upgrade has to leave
    # the database untouched, so that the previous version can be run again
    IO.puts("Validating version upgrade..")
    VersionUpgrade.validate_before_migrations()

    Enum.each(repos(), fn repo ->
      IO.puts("Migrating #{inspect(repo)}")
      Migrator.run(repo, Migrator.migrations_path(repo), :up, all: true)
    end)
  end

  # The script path comes from the repo configuration of the release, not from
  # the user input.
  # sobelow_skip ["RCE.CodeModule"]
  @spec seed_repo(Ecto.Repo.t()) :: :ok
  defp seed_repo(repo) do
    # resolves next to the migrations, i.e. `priv/<repo>/seeds.exs` of the repo's OTP app
    script = Migrator.migrations_path(repo, "seeds.exs")

    if File.regular?(script) do
      IO.puts("Seeding #{inspect(repo)} from #{script}")
      Code.eval_file(script)
    end

    :ok
  end
end
