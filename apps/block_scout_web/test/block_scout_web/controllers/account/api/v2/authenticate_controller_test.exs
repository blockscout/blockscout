defmodule BlockScoutWeb.Account.API.V2.AuthenticateControllerTest do
  use BlockScoutWeb.ConnCase, async: false

  alias Explorer.Account.Identity
  alias Explorer.Chain.Address
  alias Explorer.ThirdPartyIntegrations.Dynamic
  alias Explorer.ThirdPartyIntegrations.Dynamic.Strategy

  import Mox

  describe "POST api/account/v2/send_otp" do
    test "send OTP successfully", %{conn: conn} do
      Tesla.Test.expect_tesla_call(
        times: 3,
        returns: fn
          %{
            method: :post,
            url: "https://example.com/oauth/token",
            query: [],
            headers: [{"Content-type", "application/json"}],
            body:
              ~s|{"audience":"https://example.com/api/v2/","client_id":"client_id","client_secret":"secrets","grant_type":"client_credentials"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s({"access_token": "test_token", "expires_in": 86400})
             }}

          %Tesla.Env{
            method: :get,
            url: "https://example.com/api/v2/users",
            query: [q: ~s|email:"test@example.com" OR user_metadata.email:"test@example.com"|],
            headers: [{"accept", "application/json"}, {"authorization", "Bearer test_token"}],
            body: ""
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|[]|
             }}

          %{
            method: :post,
            url: "https://example.com/passwordless/start",
            query: %{},
            headers: [
              {"accept", "application/json"},
              {"auth0-forwarded-for", _ip},
              {"content-type", "application/json"}
            ],
            body:
              ~s|{"send":"code","connection":"email","email":"test@example.com","client_id":"client_id","client_secret":"secrets"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|{"_id":"123","email":"test@example.com","email_verified":false}|
             }}
        end
      )

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/account/v2/send_otp", JSON.encode!(%{"email" => "test@example.com"}))
        |> json_response(200)

      assert response == %{"message" => "Success"}
    end

    test "send OTP for linking email to an existing account successfully", %{conn: conn} do
      auth = :auth |> build() |> put_in([Access.key!(:info), Access.key!(:email)], nil)
      {:ok, user} = Identity.find_or_create(auth)
      conn_with_user = Plug.Test.init_test_session(conn, current_user: user)

      Tesla.Test.expect_tesla_call(
        times: 3,
        returns: fn
          %{
            method: :post,
            url: "https://example.com/oauth/token",
            query: [],
            headers: [{"Content-type", "application/json"}],
            body:
              ~s|{"audience":"https://example.com/api/v2/","client_id":"client_id","client_secret":"secrets","grant_type":"client_credentials"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s({"access_token": "test_token", "expires_in": 86400})
             }}

          %Tesla.Env{
            method: :get,
            url: "https://example.com/api/v2/users",
            query: [q: ~s|email:"test@example.com" OR user_metadata.email:"test@example.com"|],
            headers: [{"accept", "application/json"}, {"authorization", "Bearer test_token"}],
            body: ""
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|[]|
             }}

          %{
            method: :post,
            url: "https://example.com/passwordless/start",
            query: %{},
            headers: [
              {"accept", "application/json"},
              {"auth0-forwarded-for", _ip},
              {"content-type", "application/json"}
            ],
            body:
              ~s|{"send":"code","connection":"email","email":"test@example.com","client_id":"client_id","client_secret":"secrets"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|{"_id":"123","email":"test@example.com","email_verified":false}|
             }}
        end
      )

      response =
        conn_with_user
        |> put_req_header("content-type", "application/json")
        |> post("/api/account/v2/send_otp", JSON.encode!(%{"email" => "test@example.com"}))
        |> json_response(200)

      assert response == %{"message" => "Success"}
    end

    test "do not send OTP for linking email to an existing account when email is already linked", %{conn: conn} do
      auth = :auth |> build() |> put_in([Access.key!(:info), Access.key!(:email)], nil)
      {:ok, user} = Identity.find_or_create(auth)
      conn_with_user = Plug.Test.init_test_session(conn, current_user: user)

      Tesla.Test.expect_tesla_call(
        times: 3,
        returns: fn
          %{
            method: :post,
            url: "https://example.com/oauth/token",
            query: [],
            headers: [{"Content-type", "application/json"}],
            body:
              ~s|{"audience":"https://example.com/api/v2/","client_id":"client_id","client_secret":"secrets","grant_type":"client_credentials"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s({"access_token": "test_token", "expires_in": 86400})
             }}

          %Tesla.Env{
            method: :get,
            url: "https://example.com/api/v2/users",
            query: [q: ~s|email:"test@example.com" OR user_metadata.email:"test@example.com"|],
            headers: [{"accept", "application/json"}, {"authorization", "Bearer test_token"}],
            body: ""
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body:
                 ~s([{"identities":[{"connection":"email","user_id":"123","provider":"email","isSocial":false}],"user_id":"email|123","email":"test@example.com"}])
             }}

          %{
            method: :post,
            url: "https://example.com/passwordless/start",
            query: %{},
            headers: [
              {"accept", "application/json"},
              {"auth0-forwarded-for", _ip},
              {"content-type", "application/json"}
            ],
            body:
              ~s|{"send":"code","connection":"email","email":"test@example.com","client_id":"client_id","client_secret":"secrets"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|{"_id":"123","email":"test@example.com","email_verified":false}|
             }}
        end
      )

      response =
        conn_with_user
        |> put_req_header("content-type", "application/json")
        |> post("/api/account/v2/send_otp", JSON.encode!(%{"email" => "test@example.com"}))
        |> json_response(500)

      assert response == %{"message" => "Account with this email already exists"}
    end

    test "do nothing for an account with an existing email", %{conn: conn} do
      auth = build(:auth)
      {:ok, user} = Identity.find_or_create(auth)
      conn_with_user = Plug.Test.init_test_session(conn, current_user: user)

      Tesla.Test.expect_tesla_call(
        times: 3,
        returns: fn
          %{
            method: :post,
            url: "https://example.com/oauth/token",
            query: [],
            headers: [{"Content-type", "application/json"}],
            body:
              ~s|{"audience":"https://example.com/api/v2/","client_id":"client_id","client_secret":"secrets","grant_type":"client_credentials"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s({"access_token": "test_token", "expires_in": 86400})
             }}

          %Tesla.Env{
            method: :get,
            url: "https://example.com/api/v2/users",
            query: [q: ~s|email:"test@example.com" OR user_metadata.email:"test@example.com"|],
            headers: [{"accept", "application/json"}, {"authorization", "Bearer test_token"}],
            body: ""
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|[]|
             }}

          %{
            method: :post,
            url: "https://example.com/passwordless/start",
            query: %{},
            headers: [
              {"accept", "application/json"},
              {"auth0-forwarded-for", _ip},
              {"content-type", "application/json"}
            ],
            body:
              ~s|{"send":"code","connection":"email","email":"test@example.com","client_id":"client_id","client_secret":"secrets"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s|{"_id":"123","email":"test@example.com","email_verified":false}|
             }}
        end
      )

      response =
        conn_with_user
        |> put_req_header("content-type", "application/json")
        |> post("/api/account/v2/send_otp", JSON.encode!(%{"email" => "test@example.com"}))
        |> json_response(500)

      assert response == %{"message" => "This account already has an email"}
    end
  end

  describe "GET api/account/v2/siwe_message" do
    test "get SIWE message successfully", %{conn: conn} do
      address = build(:address)

      response =
        conn
        |> get("/api/account/v2/siwe_message?address=#{address.hash}")
        |> json_response(200)

      assert String.contains?(response["siwe_message"], Address.checksum(address))
    end

    test "return error for an invalid address", %{conn: conn} do
      response =
        conn
        |> get("/api/account/v2/siwe_message?address=invalid_address")
        |> json_response(422)

      assert response == %{
               "errors" => [
                 %{
                   "title" => "Invalid value",
                   "source" => %{"pointer" => "/address"},
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/"
                 }
               ]
             }
    end
  end

  describe "POST api/account/v2/authenticate_via_wallet" do
    test "authenticate via wallet successfully", %{conn: conn} do
      private_key = :crypto.strong_rand_bytes(32)
      {:ok, <<0x04, public_key_raw::binary-size(64)>>} = ExSecp256k1.create_public_key(private_key)

      <<_::binary-size(12), address_bytes::binary-size(20)>> =
        ExKeccak.hash_256(public_key_raw)

      address_string = Address.checksum(address_bytes)

      Tesla.Test.expect_tesla_call(
        times: 2,
        returns: fn
          %{
            method: :post,
            url: "https://example.com/oauth/token",
            query: [],
            headers: [{"Content-type", "application/json"}],
            body:
              ~s|{"audience":"https://example.com/api/v2/","client_id":"client_id","client_secret":"secrets","grant_type":"client_credentials"}|
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: ~s({"access_token": "test_token", "expires_in": 86400})
             }}

          %Tesla.Env{
            method: :get,
            url: "https://example.com/api/v2/users",
            query: _,
            headers: [{"accept", "application/json"}, {"authorization", "Bearer test_token"}],
            body: ""
          },
          _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body:
                 ~s([{"identities":[{"connection":"email","user_id":"123","provider":"email","isSocial":false}],"user_id":"email|123","email":"test@example.com","user_metadata":{"web3_address_hash":"#{address_string}"}}])
             }}
        end
      )

      message =
        conn
        |> get("/api/account/v2/siwe_message?address=#{address_string}")
        |> json_response(200)
        |> Map.get("siwe_message")

      # cspell:disable-next-line
      hash = ExKeccak.hash_256("\x19Ethereum Signed Message:\n#{byte_size(message)}" <> message)

      {:ok, {rs_binary, v}} = ExSecp256k1.sign_compact(hash, private_key)
      signature = "0x" <> Base.encode16(rs_binary <> <<v + 27>>, case: :lower)

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/account/v2/authenticate_via_wallet",
          JSON.encode!(%{"message" => message, "signature" => signature})
        )
        |> json_response(200)

      assert response["email"] == "test@example.com" and response["address_hash"] == address_string
    end

    test "return error for invalid signature", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/account/v2/authenticate_via_wallet",
          JSON.encode!(%{"message" => "test_message", "signature" => "0x1234"})
        )
        |> json_response(500)

      assert %{"message" => _error_message} = response
    end
  end

  describe "GET api/account/v2/authenticate_via_dynamic" do
    setup :set_mox_global

    test "authenticate via dynamic successfully", %{conn: conn} do
      initial_dynamic_env = Application.get_env(:explorer, Dynamic)
      initial_strategy_env = Application.get_env(:explorer, Strategy)

      Application.put_env(
        :explorer,
        Dynamic,
        Keyword.merge(initial_dynamic_env,
          enabled: true,
          env_id: "test_env",
          url: "https://app.dynamic.xyz/api/v0/sdk/test_env/.well-known/jwks"
        )
      )

      Application.put_env(
        :explorer,
        Strategy,
        Keyword.merge(initial_strategy_env, enabled: true)
      )

      on_exit(fn ->
        Application.put_env(:explorer, Dynamic, initial_dynamic_env)
        Application.put_env(:explorer, Strategy, initial_strategy_env)
      end)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: "https://app.dynamic.xyz/api/v0/sdk/test_env/.well-known/jwks"}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             headers: [{"content-type", "application/json"}],
             # cspell:disable
             body:
               ~s|{"keys":[{"alg":"RS256","e":"AQAB","ext":true,"key_ops":["verify"],"kty":"RSA","n":"xoFNCjaQg7I6oFW1LP3H733NWnvXwHCz8igFgJ9VhyjZkHfbETNIEVOSHmIHrLZln10UrPM1lwUnjV_Q27mApf0k_mNIQlH94npvAt4K9sC9tVx1TOzylBIynTEJv0u7Q2feRjwku2th6yBx2pSZxthbXzcy2trIxQE8NZHzQXgll4vJynemGFcqBS-uxlM6zdJDzfJGgs2q2d8GgZ6izc5N410zmbh7rmEuiNhVRhdBaxv2YSslI-dZiXdrcLhjLBpczBvxjJ-T6rQ7SrJTy7ELlolvP84gE0InuWDK6-RMCC_W_xc44sxPj1JRSUcH7MsGP2rzISA-HdNlSrWJEw","kid":"3SLxTe6F2vUW71mEKH0/tbt3/GxDVSb/rwqsefdZVCM=","use":"sig"}]}|
             # cspell:enable
           }}
        end
      )

      start_supervised!(Strategy)

      :timer.sleep(500)

      response =
        conn
        |> put_req_header(
          "authorization",
          # cspell:disable-next-line
          "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjNTTHhUZTZGMnZVVzcxbUVLSDAvdGJ0My9HeERWU2Ivcndxc2VmZFpWQ009In0.eyJraWQiOiI1ZDE0YzMzMS1lNWRjLTQwZDgtOGM5Yy00Zjc1N2YxMDYzMTgiLCJhdWQiOiJodHRwOi8vbG9jYWxob3N0OjMwMDAiLCJpc3MiOiJhcHAuZHluYW1pY2F1dGguY29tL3Rlc3RfZW52Iiwic3ViIjoiNDBhM2NkYTEtNjU2Yy00NzM3LTkyZjgtZWMwYzAzNjZjNTVhIiwic2lkIjoiNDkwZjA3MzgtY2IwNi00MjFkLWIxNGEtZDJhMzJhODA1NzdjIiwic2Vzc2lvbl9wdWJsaWNfa2V5IjoiMDMwNTY0OGI0Nzc4MzU3MzUwZmZhNDk3ZmJmNzQ5ZjAwOWQ3Njk2ODkzNmI5Y2E4ZGI3MzY4OGY2MzIwN2RhZGE0IiwiYWxpYXMiOiJhbGlhcyIsImVtYWlsIjoidGVzdEBleGFtcGxlLmNvbSIsImVudmlyb25tZW50X2lkIjoiOTA0ZTdiZmEtNDEyZi00NzY4LTk4YzUtOWEwMmY3Yzc0MTJkIiwiZmFtaWx5X25hbWUiOiJsbiIsImdpdmVuX25hbWUiOiJmbiIsImxpc3RzIjpbXSwibWlzc2luZ19maWVsZHMiOltdLCJ1c2VybmFtZSI6InVzZXJuYW1lIiwidmVyaWZpZWRfY3JlZGVudGlhbHMiOlt7ImFkZHJlc3MiOiIweDAzYzM2M2Y0OGM0RkUwRjJFYzZlZmJENDlGN2IxMTRiOEE2MWMxNGIiLCJjaGFpbiI6ImVpcDE1NSIsImlkIjoiNDQ2NDI4YTUtNTQxYS00OWY0LThkYmItYmIyYjhjODgwMjczIiwibmFtZV9zZXJ2aWNlIjp7fSwicHVibGljX2lkZW50aWZpZXIiOiIweDAzYzM2M2Y0OGM0RkUwRjJFYzZlZmJENDlGN2IxMTRiOEE2MWMxNGIiLCJ3YWxsZXRfbmFtZSI6Im1ldGFtYXNrIiwid2FsbGV0X3Byb3ZpZGVyIjoiYnJvd3NlckV4dGVuc2lvbiIsImZvcm1hdCI6ImJsb2NrY2hhaW4iLCJsYXN0U2VsZWN0ZWRBdCI6IjIwMjYtMDEtMDhUMDc6NDg6MTAuMzM0WiIsInNpZ25JbkVuYWJsZWQiOnRydWV9LHsiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWQiOiI2NDU4MWExMi0yZjMwLTRmZjgtOTU4OC1lMGM5NGVhMWM4OWIiLCJwdWJsaWNfaWRlbnRpZmllciI6InRlc3RAZXhhbXBsZS5jb20iLCJmb3JtYXQiOiJlbWFpbCIsInNpZ25JbkVuYWJsZWQiOnRydWUsInZlcmlmaWVkQXQiOiIyMDI1LTEyLTIzVDEwOjU1OjA5LjM2NVoifV0sImxhc3RfdmVyaWZpZWRfY3JlZGVudGlhbF9pZCI6IjQ0NjQyOGE1LTU0MWEtNDlmNC04ZGJiLWJiMmI4Yzg4MDI3MyIsImZpcnN0X3Zpc2l0IjoiMjAyNS0xMi0xOFQxMzo1Mjo1OC4yMDFaIiwibGFzdF92aXNpdCI6IjIwMjYtMDEtMDhUMDc6NDg6MTAuMzIxWiIsIm5ld191c2VyIjpmYWxzZSwibWV0YWRhdGEiOnt9LCJ2ZXJpZmllZENyZWRlbnRpYWxzSGFzaGVzIjp7ImJsb2NrY2hhaW4iOiI1NTAwMTUyZDMwMjc2MzIwMDNmZmUxOTRlMmM3YzFiYyIsImVtYWlsIjoiMjg1OGY0OWQ2YjE2Nzg3NTFlNTA0ZDQ3ODM0ZDcwMGEiLCJvYXV0aCI6ImZmMTA5N2I1MGVkMDNhNDA4MWRhMTA2NjBlMDEzMzg5In0sImhhc2hlZF9pcCI6ImMxNWE3NTgzNGVkY2JjZjI3NmQyYTQ3NmFmNmJjMTVmIiwicmVmcmVzaEV4cCI6MTc3MDQ1MDQ5MCwiaWF0IjoxNzY3ODU4NDkwLCJleHAiOjMwNjc4NjU2OTB9.S-9hkUbqr5P69xtu4qcSDbNrjUiUa4BnhvUHHSSCZ-7FHUvjRH8LXj4lGrbGIpoLAEMMdRzi8l9HkQSH7ASACP2-cm3JRDr5-p2-IN4Qm5GTo0o2ewzxxhqpNCQocUkPld6JUY-3O1XobaVCL7PNLnBUV4-jCGKkQbgpye50dezq7dqjV3CXxhpKt-80gmWxlVyIEkGENKawlvw6AUShtMYHhvqon-RqCtJsYRzGQXMdsAOkvV-0vXN8PVLk5fKJ6GInuW8hYB_i_V_HRChQnkvHsswMBj3-hEmwh5x6lZY2kq3fcoVsQI1lSaYK5ZctO-ij476o1VDgBIVmvw2Bug"
        )
        |> get("/api/account/v2/authenticate_via_dynamic")
        |> json_response(200)

      assert response["email"] == "test@example.com"
    end

    test "without bearer token returns error", %{conn: conn} do
      initial_dynamic_env = Application.get_env(:explorer, Dynamic)
      initial_strategy_env = Application.get_env(:explorer, Strategy)

      Application.put_env(
        :explorer,
        Dynamic,
        Keyword.merge(initial_dynamic_env,
          enabled: true,
          env_id: "test_env",
          url: "https://app.dynamic.xyz/api/v0/sdk/test_env/.well-known/jwks"
        )
      )

      Application.put_env(
        :explorer,
        Strategy,
        Keyword.merge(initial_strategy_env, enabled: true)
      )

      on_exit(fn ->
        Application.put_env(:explorer, Dynamic, initial_dynamic_env)
        Application.put_env(:explorer, Strategy, initial_strategy_env)
      end)

      response =
        conn
        |> get("/api/account/v2/authenticate_via_dynamic")
        |> json_response(401)

      assert response == %{"message" => "No Bearer token"}
    end

    test "without config returns error", %{conn: conn} do
      response =
        conn
        |> put_req_header(
          "authorization",
          "Bearer some_token"
        )
        |> get("/api/account/v2/authenticate_via_dynamic")
        |> json_response(500)

      assert response == %{"message" => "Dynamic integration is disabled"}
    end
  end
end
