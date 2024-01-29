defmodule Explorer.Repo.Migrations.AddTokensCatalogedIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :tokens,
        ~w(cataloged)a,
        name: :uncataloged_tokens,
        where: ~s|"cataloged" = false|
      )
    )
  end
end
