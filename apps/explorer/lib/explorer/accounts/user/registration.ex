defmodule Explorer.Accounts.User.Registration do
  @moduledoc """
  Represents the data required to register a new account.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.User.Registration

  typed_embedded_schema do
    field(:username, :string, null: false)
    field(:email, :string, null: false)
    field(:password, :string, null: false)
    field(:password_confirmation, :string, null: false)
  end

  @fields ~w(email password password_confirmation username)a

  def changeset(params \\ %{}) do
    %Registration{}
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> validate_format(:email, ~r/@/)
  end
end
