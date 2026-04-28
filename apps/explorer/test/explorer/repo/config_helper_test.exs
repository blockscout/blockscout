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

    test "parse params from database url with hyphen in database name" do
      database_url = "postgresql://test_username:test_password@host-name.test.com:7777/test-database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "test_password"
      assert result[:hostname] == "host-name.test.com"
      assert result[:port] == "7777"
      assert result[:database] == "test-database"
    end

    test "parse params from database url with hyphen in database user name" do
      database_url = "postgresql://test-username:password@hostname.test.com:7777/database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test-username"
      assert result[:password] == "password"
      assert result[:hostname] == "hostname.test.com"
      assert result[:port] == "7777"
      assert result[:database] == "database"
    end

    test "parse params from database url with special characters in password" do
      database_url = "postgresql://test_username:awN!l#W*g$P%t-l^.q&d@hostname.test.com:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "awN!l#W*g$P%t-l^.q&d"
      assert result[:hostname] == "hostname.test.com"
      assert result[:port] == "7777"
      assert result[:database] == "test_database"
    end

    test "parse params from database url with encoded special characters in password" do
      database_url = "postgresql://test_username:pass%23@hostname.test.com:7777/test_database"

      result = ConfigHelper.get_db_config(%{url: database_url, env_func: fn _ -> nil end})

      assert result[:username] == "test_username"
      assert result[:password] == "pass#"
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

  describe "ecto_ssl_mode/2" do
    test "defaults to require when mode is not set" do
      assert ConfigHelper.ecto_ssl_mode(nil, fn _ -> nil end) == "require"
    end

    test "reads sslmode from database url" do
      database_url = "postgresql://test:test@localhost:5432/test_db?sslmode=verify-full"

      assert ConfigHelper.ecto_ssl_mode(database_url, fn _ -> nil end) == "verify-full"
    end

    test "ECTO_SSL_MODE has precedence over database url sslmode" do
      database_url = "postgresql://test:test@localhost:5432/test_db?sslmode=disable"

      env_func = fn
        "ECTO_SSL_MODE" -> "verify-ca"
        _ -> nil
      end

      assert ConfigHelper.ecto_ssl_mode(database_url, env_func) == "verify-ca"
    end

    test "raises on invalid ssl mode" do
      env_func = fn
        "ECTO_SSL_MODE" -> "invalid-mode"
        _ -> nil
      end

      assert_raise ArgumentError, ~r/Unsupported ECTO_SSL_MODE value/, fn ->
        ConfigHelper.ecto_ssl_mode(nil, env_func)
      end
    end
  end

  describe "ssl_options/2" do
    test "maps disable to ssl false" do
      env_func = fn
        "ECTO_SSL_MODE" -> "disable"
        _ -> nil
      end

      assert ConfigHelper.ssl_options(nil, env_func) == [ssl: false]
    end

    test "maps allow to verify_none SSL" do
      env_func = fn
        "ECTO_SSL_MODE" -> "allow"
        _ -> nil
      end

      assert ConfigHelper.ssl_options(nil, env_func) == [ssl: [verify: :verify_none]]
    end

    test "maps prefer to verify_none SSL" do
      env_func = fn
        "ECTO_SSL_MODE" -> "prefer"
        _ -> nil
      end

      assert ConfigHelper.ssl_options(nil, env_func) == [ssl: [verify: :verify_none]]
    end

    test "maps require to verify_none SSL" do
      env_func = fn
        "ECTO_SSL_MODE" -> "require"
        _ -> nil
      end

      assert ConfigHelper.ssl_options(nil, env_func) == [ssl: [verify: :verify_none]]
    end

    test "maps verify-ca to peer verification without SNI" do
      env_func = fn
        "ECTO_SSL_MODE" -> "verify-ca"
        _ -> nil
      end

      ssl_options = ConfigHelper.ssl_options(nil, env_func)[:ssl]

      assert ssl_options[:verify] == :verify_peer
      assert ssl_options[:server_name_indication] == :disable
      assert ssl_options[:cacerts] == :public_key.cacerts_get()
    end

    test "maps verify-full to secure Postgrex defaults" do
      env_func = fn
        "ECTO_SSL_MODE" -> "verify-full"
        _ -> nil
      end

      assert ConfigHelper.ssl_options(nil, env_func) == [ssl: true]
    end
  end
end
