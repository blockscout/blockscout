defmodule Mix.Tasks.Ecto.Gen.DataMigration do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator
  import Mix.{Ecto, EctoSQL}

  @shortdoc "Generates a new data migration for the repo"

  @aliases [
    r: :repo
  ]

  @switches [
    change: :string,
    repo: [:string, :keep],
    no_compile: :boolean,
    no_deps_check: :boolean,
    migrations_path: :string,
    events: :boolean
  ]

  @moduledoc """
  Generates a data migration.

  The repository must be set under `:ecto_repos` in the
  current app configuration or given via the `-r` option.

  ## Examples

      $ mix ecto.gen.data_migration migrate_things_to_other_things
      $ mix ecto.gen.data_migration migrate_some_events --events

  The generated migration filename will be prefixed with the current
  timestamp in UTC which is used for versioning and ordering.

  By default, the migration will be generated to the
  "priv/YOUR_REPO/data_migrations" directory of the current application
  but it can be configured to be any subdirectory of `priv` by
  specifying the `:priv` key under the repository configuration.

  This generator will automatically open the generated file if
  you have `ECTO_EDITOR` set in your environment variable.

  ## Command line options

    * `-r`, `--repo` - the repo to generate migration for
    * `--no-compile` - does not compile applications before running
    * `--no-deps-check` - does not check dependencies before running
    * `--events` - generate a script with convenience methods for migrating data from `logs` to `celo_contract_events`
    * `--migrations-path` - the path to run the migrations from, defaults to `priv/repo/data_migrations`

  ## Configuration

  If the current app configuration specifies a custom migration module
  the generated migration code will use that rather than the default
  `Ecto.Migration`:

      config :ecto_sql, migration_module: MyApplication.CustomMigrationModule

  """

  @impl true
  def run(args) do
    repos = parse_repo(args)

    Enum.map(repos, fn repo ->
      case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
        {opts, [name]} ->
          ensure_repo(repo, args)
          path = opts[:migrations_path] || Path.join(source_repo_priv(repo), "data_migrations")
          base_name = "#{underscore(name)}.exs"
          file = Path.join(path, "#{timestamp()}_#{base_name}")
          unless File.dir?(path), do: create_directory(path)

          fuzzy_path = Path.join(path, "*_#{base_name}")

          if Path.wildcard(fuzzy_path) != [] do
            Mix.raise("migration can't be created, there is already a migration file with name #{name}.")
          end

          # The :change option may be used by other tasks but not the CLI
          assigns = [
            mod: Module.concat([repo, Migrations, camelize(name)]),
            change: opts[:change],
            event: opts[:events]
          ]

          create_file(file, migration_template(assigns))

          # credo:disable-for-next-line
          if open?(file) and Mix.shell().yes?("Do you want to run this migration?") do
            # credo:disable-for-next-line
            Mix.Task.run("ecto.migrate", ["-r", inspect(repo), "--migrations-path", path])
          end

          file

        {_, _} ->
          Mix.raise(
            "expected ecto.gen.data_migration to receive the migration file name, " <>
              "got: #{inspect(Enum.join(args, " "))}"
          )
      end
    end)
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Explorer.Repo.Migrations.DataMigration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    <%= if @event do %># event topics to migrate from logs table
    @topics [] <% end %>

    use <%= inspect migration_module() %>
    import Ecto.Query

    @doc "Undo the data migration"
    def down, do: :ok

    @doc "Returns an ecto query that gives the next batch / page of source rows to be processed"
    def page_query(start_of_page) do
    <%= if @event do %> event_page_query(start_of_page) <% end %>
    end

    @doc "Perform the transformation with the list of source rows to operate upon, returns a list of inserted / modified ids"
    def do_change(ids) do
    <%= if @event do %> event_change(ids) <% end %>
    end

    @doc "Handle unsuccessful insertions"
    def handle_non_insert(ids), do: raise "Failed to insert - \#{inspect(ids)}"
  end
  """)
end
