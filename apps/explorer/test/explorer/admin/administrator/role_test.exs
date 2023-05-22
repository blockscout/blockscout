defmodule Explorer.Admin.Administrator.RoleTest do
  use ExUnit.Case

  alias Explorer.Admin.Administrator.Role

  describe "cast/1" do
    test "with a valid role atom" do
      assert Role.cast(:owner) == {:ok, :owner}
    end

    test "with a valid role string" do
      assert Role.cast("owner") == {:ok, :owner}
    end

    test "with an invalid value" do
      assert Role.cast("admin") == :error
    end
  end

  describe "dump/1" do
    test "with a valid role atom" do
      assert Role.dump(:owner) == {:ok, "owner"}
    end

    test "with an invalid role" do
      assert Role.dump(:admin) == :error
    end
  end

  describe "load/1" do
    test "with a valid role string" do
      assert Role.load("owner") == {:ok, :owner}
    end

    test "with an invalid role value" do
      assert Role.load("admin") == :error
    end
  end

  test "type/0" do
    assert Role.type() == :string
  end
end
