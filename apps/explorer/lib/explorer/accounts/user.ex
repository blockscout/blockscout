defmodule Explorer.Accounts.User do
  @moduledoc """
  An Explorer user.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Bcrypt
  alias Ecto.Changeset
  alias Explorer.Accounts.{User, UserContact}

  @typedoc """
  * `:username` - A unique username
  * `:password_hash` - Encrypted password
  * `:contacts` - List of `t:UserContact.t/0`
  """
  typed_schema "users" do
    field(:username, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    has_many(:contacts, UserContact)
    timestamps()
  end

  @doc false
  def changeset(%User{} = user, params \\ %{}) do
    user
    |> cast(params, ~w(password_hash password username)a)
    |> hash_password()
    |> unique_constraint(:username, name: :unique_username)
    |> cast_assoc(:contacts)
  end

  defp hash_password(%Changeset{} = changeset) do
    if password = get_change(changeset, :password) do
      put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    else
      changeset
    end
  end
end
