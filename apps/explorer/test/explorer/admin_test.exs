defmodule Explorer.AdminTest do
  use Explorer.DataCase

  alias Explorer.Admin

  describe "owner/0" do
    test "returns the owner if configured" do
      expected_admin = insert(:administrator)
      assert {:ok, admin} = Admin.owner()
      assert admin.id == expected_admin.id
    end

    test "returns error if no owner configured" do
      assert {:error, :not_found} = Admin.owner()
    end
  end

  describe "register_owner/1" do
    @valid_registration_params %{
      username: "blockscoutuser",
      email: "blockscoutuser@blockscout",
      password: "password",
      password_confirmation: "password"
    }
    test "registers a new owner" do
      assert {:ok, result} = Admin.register_owner(@valid_registration_params)
      assert result.admin.role == "owner"
      assert result.user.username == @valid_registration_params.username
      assert Enum.at(result.user.contacts, 0).email == @valid_registration_params.email
    end

    test "returns error with invalid changeset params" do
      assert {:error, _changeset} = Admin.register_owner(%{})
    end

    test "returns error if owner already exists" do
      insert(:administrator)
      assert {:error, changeset} = Admin.register_owner(@valid_registration_params)
      changeset_errors = changeset_errors(changeset)
      assert Enum.at(changeset_errors.role, 0) =~ "taken"
    end
  end

  describe "from_user/1" do
    test "returns record if user is admin" do
      admin = insert(:administrator)

      assert {:ok, result} = Admin.from_user(admin.user)
      assert result.id == admin.id
    end

    test "returns error if user is not an admin" do
      user = insert(:user)
      assert {:error, :not_found} == Admin.from_user(user)
    end
  end
end
