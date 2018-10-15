defmodule Explorer.Admin.Administrator do
  @moduledoc """
  Represents a user with administrative privileges.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Explorer.Accounts.User
  alias Explorer.Admin.Administrator

  @typedoc """
  * `:role` - Administrator's role determining permission level
  * `:user` - The `t:User.t/0` that is an admin
  * `:user_id` - User foreign key
  """
  @type t :: %Administrator{
          role: String.t(),
          user: User.t() | %Ecto.Association.NotLoaded{}
        }

  schema "administrators" do
    field(:role, :string)
    belongs_to(:user, User)

    timestamps()
  end

  @required_attrs ~w(role user_id)a
  @valid_roles ~w(owner)

  @doc false
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_attrs)
    |> validate_required(@required_attrs)
    |> validate_inclusion(:role, @valid_roles)
    |> assoc_constraint(:user)
    |> unique_constraint(:role, name: :owner_role_limit)
  end
end
