defmodule Explorer.Repo.ConfigHelperTest do
  use Explorer.DataCase

  alias Explorer.Repo.ConfigHelper

  describe "get_db_config/1" do
    test "parse params from database url" do
      database_url = "postgresql://test_username:test_password@127.8.8.1:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "test_password"
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "parse params from database url with hyphen in hostname" do
      database_url = "postgresql://test_username:test_password@host-name.test.com:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "test_password"
      assert result[:hostname] == "host-name.test.com"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "parse params from database url with special characters in password" do
      database_url = "postgresql://test_username:awN!l#W*g$P%t-l^q&d@hostname.test.com:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "awN!l#W*g$P%t-l^q&d"
      assert result[:hostname] == "hostname.test.com"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "get username without password" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == ""
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "get hostname instead of ip" do
      database_url = "postgresql://test_username:@cooltesthost:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == ""
      assert result[:hostname] == "cooltesthost"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "overwrite postgrex vars param with database url" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      vars = %{"PGUSER" => "postgrex_user", "PGPASSWORD" => "postgrex_password"}
      func = fn v -> vars[v] end
      result = ConfigHelper.get_db_config(%{url: database_url, env_func: func})

      assert result[:username] == "test_username"
      assert result[:password] == ""
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "overwrite database password param with empty DATABASE_URL password" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      vars = %{"PGUSER" => "postgrex_user", "PGPASSWORD" => "postgrex_password"}
      func = fn v -> vars[v] end
      result = ConfigHelper.get_db_config(%{url: database_url, env_func: func})

      assert result[:username] == "test_username"
      assert result[:password] == ""
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end
  end
end
