defmodule Explorer.Accounts.UserContact do
  @moduledoc """
  A individual form of contacting the user.

  Users can have more than one contact email. Each email must be unique for a
  given user. Additionally, a user can only have 1 primary contact at a time.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Accounts.{User, UserContact}

  schema "user_contacts" do
    field(:email, :string)
    field(:primary, :boolean, default: false)
    field(:verified, :boolean, default: false)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(%UserContact{} = user_contact, params \\ %{}) do
    user_contact
    |> cast(params, ~w(email primary user_id verified)a)
    |> validate_required(~w(email)a)
    |> validate_format(:email, ~r/@/)
    |> format_email()
    |> unique_constraint(:email, name: :email_unique_unique_user)
    |> unique_constraint(:primary, name: :one_primary_per_user)
  end

  defp format_email(%Changeset{valid?: true, changes: %{email: email}} = changeset) do
    formatted_email =
      email
      |> String.trim()
      |> String.downcase()

    put_change(changeset, :email, formatted_email)
  end

  defp format_email(%Changeset{} = changeset), do: changeset
end
