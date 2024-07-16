defmodule Explorer.Accounts.User.Authenticate do
  @moduledoc """
  Represents the data required to authenticate a user.
  """

  use Explorer.Schema

  import Ecto.Changeset

  typed_embedded_schema do
    field(:username, :string, null: false)
    field(:password, :string, null: false)
  end

  @required_attrs ~w(password username)a

  def changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
