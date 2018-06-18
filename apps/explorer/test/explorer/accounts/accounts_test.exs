defmodule Explorer.AccountsTest do
  use Explorer.DataCase

  alias Explorer.Accounts

  describe "register_new_account/1" do
    test "with valid params" do
      params = %{
        username: "poanetwork",
        password: "testtest",
        password_confirmation: "testtest",
        email: "test@poanetwork.com"
      }

      assert {:ok, user} = Accounts.register_new_account(params)

      [contact] = user.contacts

      assert user.username == params.username
      refute user.password_hash == params.password
      assert Comeonin.Bcrypt.checkpw(params.password, user.password_hash)
      assert contact.email == params.email
      assert contact.primary
      refute contact.verified
    end

    test "with duplicate username" do
      params = %{
        username: "poanetwork",
        password: "testtest",
        password_confirmation: "testtest",
        email: "test@poanetwork.com"
      }

      assert {:ok, _} = Accounts.register_new_account(params)
      assert {:error, changeset} = Accounts.register_new_account(params)
      refute changeset.valid?
      errors = changeset_errors(changeset)
      assert hd(errors.username) =~ "taken"
    end

    test "with invalid email format" do
      params = %{
        username: "poanetwork",
        password: "testtest",
        password_confirmation: "testtest",
        email: "test"
      }

      assert {:error, changeset} = Accounts.register_new_account(params)
      errors = changeset_errors(changeset)
      assert hd(errors.email) =~ "format"
    end

    test "with invalid password" do
      params = %{
        username: "poanetwork",
        password: "test",
        password_confirmation: "test",
        email: "test@poanetwork.com"
      }

      # Length check
      assert {:error, changeset} = Accounts.register_new_account(params)
      errors = changeset_errors(changeset)
      assert hd(errors.password) =~ "at least"

      # Confirmation check
      params = %{params | password: "testtest"}
      assert {:error, changeset} = Accounts.register_new_account(params)
      errors = changeset_errors(changeset)
      assert hd(errors.password_confirmation) =~ "match"
    end
  end
end
