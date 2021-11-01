defmodule Explorer.Accounts.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account_identities" do
    field(:uid, :string)

    timestamps()
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:uid])
    |> validate_required([:uid])
  end
end
