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

    test "get username without password" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      refute result[:password]
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "get hostname instead of ip" do
      database_url = "postgresql://test_username:@cooltesthost:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      refute result[:password]
      assert result[:hostname] == "cooltesthost"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "overwrite database url param with postgrex vars" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      vars = %{"PGUSER" => "postgrex_user", "PGPASSWORD" => "postgrex_password"}
      func = fn v -> vars[v] end
      result = ConfigHelper.get_db_config(%{url: database_url, env_func: func})

      assert result[:username] == "postgrex_user"
      assert result[:password] == "postgrex_password"
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "overwrite database url param and postgrex with app env" do
      database_url = "postgresql://test_username:@127.8.8.1:7777/test_database"

      vars = %{"PGUSER" => "postgrex_user", "PGPASSWORD" => "postgrex_password", "DATABASE_USER" => "app_db_user"}
      func = fn v -> vars[v] end

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: func})

      assert result[:username] == "app_db_user"
      assert result[:password] == "postgrex_password"
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "overwrite database password param with empty PGPASSWORD" do
      database_url = "postgresql://test_username:test_password@127.8.8.1:7777/test_database"

      vars = %{"PGUSER" => "postgrex_user", "PGPASSWORD" => ""}
      func = fn v -> vars[v] end
      result = ConfigHelper.get_db_config(%{url: database_url, env_func: func})

      assert result[:username] == "postgrex_user"
      assert result[:password] == ""
      assert result[:hostname] == "127.8.8.1"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "uses only DATABASE_* env vars" do
      env_db_user = "env-user"
      env_db_password = "env-password"
      env_db_host = "env-host"
      env_db_port = "env-port"
      env_db_name = "env-db-name"

      vars = %{
        "PGUSER" => "postgrex_user",
        "PGPASSWORD" => "postgrex_password",
        "DATABASE_USER" => env_db_user,
        "DATABASE_PASSWORD" => env_db_password,
        "DATABASE_HOSTNAME" => env_db_host,
        "DATABASE_PORT" => env_db_port,
        "DATABASE_DB" => env_db_name
      }

      func = fn v -> vars[v] end
      result = ConfigHelper.get_db_config(%{url: "", env_func: func})

      assert result[:username] == env_db_user
      assert result[:password] == env_db_password
      assert result[:hostname] == env_db_host
      assert result[:port] == env_db_port
      assert result[:database] == env_db_name
    end
  end
end
