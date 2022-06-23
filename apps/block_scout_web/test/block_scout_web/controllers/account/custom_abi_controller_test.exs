defmodule BlockScoutWeb.Account.CustomABIControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Models.UserFromAuth
  alias Ueberauth.Strategy.Auth0
  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth

  @custom_abi "[{\"type\":\"function\",\"outputs\":[{\"type\":\"string\",\"name\":\"\"}],\"name\":\"name\",\"inputs\":[],\"constant\":true}]"

  setup do
    auth = %Auth{
      info: %Info{
        birthday: nil,
        description: nil,
        email: "john@blockscout.com",
        first_name: nil,
        image: "https://avatars.githubusercontent.com/u/666666=4",
        last_name: nil,
        location: nil,
        name: "John Snow",
        nickname: "johnnny",
        phone: nil,
        urls: %{profile: nil, website: nil}
      },
      provider: :auth0,
      strategy: Auth0,
      uid: "github|666666"
    }

    {:ok, user} = UserFromAuth.find_or_create(auth)

    {:ok, account_session_params: user}
  end

  describe "test custom ABI functionality" do
    test "custom ABI page opens correctly", %{conn: conn, account_session_params: account_session_params} do
      result_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> get(custom_abi_path(conn, :index))

      assert html_response(result_conn, 200) =~ "Create a Custom ABI to interact with contracts."
    end

    test "do not add custom ABI with wrong ABI", %{conn: conn, account_session_params: account_session_params} do
      contract_address = insert(:address, contract_code: "0x0102")

      custom_abi = %{
        "name" => "1",
        "address_hash" => to_string(contract_address),
        "abi" => ""
      }

      result_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))

      assert html_response(result_conn, 200) =~ "Add Custom ABI"
      assert html_response(result_conn, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn, 200) =~ "Required"

      result_conn_1 =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => Map.put(custom_abi, "abi", "123")}))

      assert html_response(result_conn_1, 200) =~ "Add Custom ABI"
      assert html_response(result_conn_1, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn_1, 200) =~ "Invalid format"

      result_conn_2 =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> get(custom_abi_path(conn, :index))

      assert html_response(result_conn_2, 200) =~ "Create a Custom ABI to interact with contracts."
      refute html_response(result_conn_2, 200) =~ to_string(contract_address.hash)
    end

    test "add one custom abi and do not allow to create duplicates", %{
      conn: conn,
      account_session_params: account_session_params
    } do
      contract_address = insert(:contract_address, contract_code: "0x0102")

      custom_abi = %{
        "name" => "1",
        "address_hash" => to_string(contract_address),
        "abi" => @custom_abi
      }

      result_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))

      assert redirected_to(result_conn) == custom_abi_path(conn, :index)

      result_conn_2 = get(result_conn, custom_abi_path(conn, :index))
      assert html_response(result_conn_2, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn_2, 200) =~ "Create a Custom ABI to interact with contracts."

      result_conn_1 =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))

      assert html_response(result_conn_1, 200) =~ "Add Custom ABI"
      assert html_response(result_conn_1, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn_1, 200) =~ "Custom ABI for this address has already been added before"
    end

    test "show error on address which is not smart contract", %{
      conn: conn,
      account_session_params: account_session_params
    } do
      contract_address = insert(:address)

      custom_abi = %{
        "name" => "1",
        "address_hash" => to_string(contract_address),
        "abi" => @custom_abi
      }

      result_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))

      assert html_response(result_conn, 200) =~ "Add Custom ABI"
      assert html_response(result_conn, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn, 200) =~ "Address is not a smart contract"
    end

    test "user can add up to 15 custom ABIs", %{
      conn: conn,
      account_session_params: account_session_params
    } do
      prepared_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)

      addresses =
        Enum.map(1..15, fn _x ->
          address = insert(:contract_address, contract_code: "0x0102")

          custom_abi = %{
            "name" => "1",
            "address_hash" => to_string(address),
            "abi" => @custom_abi
          }

          assert prepared_conn
                 |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))
                 |> redirected_to() == custom_abi_path(conn, :index)

          to_string(address.hash)
        end)

      assert abi_list =
               prepared_conn
               |> get(custom_abi_path(conn, :index))
               |> html_response(200)

      Enum.each(addresses, fn address -> assert abi_list =~ address end)

      address = insert(:contract_address, contract_code: "0x0102")

      custom_abi = %{
        "name" => "1",
        "address_hash" => to_string(address),
        "abi" => @custom_abi
      }

      assert error_form =
               prepared_conn
               |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))
               |> html_response(200)

      assert error_form =~ "Add Custom ABI"
      assert error_form =~ "Max 15 ABIs per account"
      assert error_form =~ to_string(address.hash)

      assert abi_list_new =
               prepared_conn
               |> get(custom_abi_path(conn, :index))
               |> html_response(200)

      Enum.each(addresses, fn address -> assert abi_list_new =~ address end)

      refute abi_list_new =~ to_string(address.hash)
      assert abi_list_new =~ "You can create up to 15 Custom ABIs per account."
    end

    test "after adding custom ABI on address page appear Read/Write Contract tab", %{
      conn: conn,
      account_session_params: account_session_params
    } do
      contract_address = insert(:contract_address, contract_code: "0x0102")

      custom_abi = %{
        "name" => "1",
        "address_hash" => to_string(contract_address),
        "abi" =>
          "[{\"type\":\"function\",\"outputs\":[{\"type\":\"string\",\"name\":\"\"}],\"name\":\"name\",\"inputs\":[],\"constant\":true},{\"type\":\"function\",\"outputs\":[{\"type\":\"bool\",\"name\":\"success\"}],\"name\":\"approve\",\"inputs\":[{\"type\":\"address\",\"name\":\"_spender\"},{\"type\":\"uint256\",\"name\":\"_value\"}],\"constant\":false}]"
      }

      result_conn =
        conn
        |> Plug.Test.init_test_session(current_user: account_session_params)
        |> post(custom_abi_path(conn, :create, %{"custom_abi" => custom_abi}))

      assert redirected_to(result_conn) == custom_abi_path(conn, :index)

      result_conn_2 = get(result_conn, custom_abi_path(conn, :index))
      assert html_response(result_conn_2, 200) =~ to_string(contract_address.hash)
      assert html_response(result_conn_2, 200) =~ "Create a Custom ABI to interact with contracts."

      assert contract_page =
               result_conn
               |> get(address_contract_path(result_conn, :index, to_string(contract_address)))
               |> html_response(200)

      assert contract_page =~ "Write Contract"
      assert contract_page =~ "Read Contract"
    end
  end
end
