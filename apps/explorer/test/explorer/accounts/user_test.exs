defmodule Explorer.Accounts.UserTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Explorer.Accounts.User

  describe "changeset/2" do
    test "hashes password when present in changes" do
      changeset = User.changeset(%User{}, %{})
      refute changeset.changes[:password_hash]

      changeset = User.changeset(%User{}, %{password: "test"})
      assert changeset.changes[:password_hash]
      refute changeset.changes.password == changeset.changes.password_hash
    end

    test "with contacts present" do
      params = %{
        contacts: [
          %{
            email: "test@poanetwork.com"
          }
        ]
      }

      changeset = User.changeset(%User{}, params)
      assert %Changeset{} = changeset.changes.contacts |> Enum.at(0)
    end
  end
end
