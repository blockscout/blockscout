defmodule Explorer.Admin.Administrator do
  @moduledoc """
  Represents a user with administrative privileges.
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.User

  @typedoc """
  * `:role` - Administrator's role determining permission level
  * `:user` - The `t:User.t/0` that is an admin
  * `:user_id` - User foreign key
  """
  typed_schema "administrators" do
    field(:role, :string, null: false)
    belongs_to(:user, User, null: false)

    timestamps()
  end

  @required_attrs ~w(role user_id)a

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
    |> assoc_constraint(:user)
    |> unique_constraint(:role, name: :owner_role_limit)
  end
end
