defmodule Explorer.AccountsTest do
  use Explorer.DataCase

  alias Ecto.Changeset
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

  describe "authenticate/1" do
    setup do
      user = insert(:user)
      [user: user]
    end

    test "returns user when credentials are valid", %{user: user} do
      params = %{
        username: user.username,
        password: "password"
      }

      assert {:ok, result_user} = Accounts.authenticate(params)
      assert result_user.id == user.id
    end

    test "returns error when params are invalid" do
      assert {:error, %Changeset{}} = Accounts.authenticate(%{})
    end

    test "returns error when user isn't found" do
      params = %{
        username: "testuser",
        password: "password"
      }

      assert {:error, :invalid_credentials} == Accounts.authenticate(params)
    end

    test "returns error when password doesn't match", %{user: user} do
      params = %{
        username: user.username,
        password: "badpassword"
      }

      assert {:error, :invalid_credentials} == Accounts.authenticate(params)
    end
  end

  describe "fetch_user/1" do
    test "returns user when id is valid" do
      user = insert(:user)
      assert {:ok, _} = Accounts.fetch_user(user.id)
    end

    test "return error when id is invalid" do
      assert {:error, :not_found} == Accounts.fetch_user(1)
    end
  end
end
