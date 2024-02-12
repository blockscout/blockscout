defmodule Explorer.Migrator.MigrationStatus do
  @moduledoc """
  Module is responsible for keeping the current status of background migrations.
  """
  use Explorer.Schema

  alias Explorer.Repo

  @primary_key false
  typed_schema "migrations_status" do
    field(:migration_name, :string)
    # ["started", "completed"]
    field(:status, :string)

    timestamps()
  end

  @doc false
  def changeset(migration_status \\ %__MODULE__{}, params) do
    cast(migration_status, params, [:migration_name, :status])
  end

  def get_status(migration_name) do
    Repo.one(from(ms in __MODULE__, where: ms.migration_name == ^migration_name, select: ms.status))
  end

  def set_status(migration_name, status) do
    %{migration_name: migration_name, status: status}
    |> changeset()
    |> Repo.insert(on_conflict: {:replace_all_except, [:inserted_at]}, conflict_target: :migration_name)
  end
end
