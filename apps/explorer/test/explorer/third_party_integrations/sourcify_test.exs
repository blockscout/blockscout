# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.ThirdPartyIntegrations.SourcifyTest do
  use ExUnit.Case, async: false

  alias Explorer.ThirdPartyIntegrations.Sourcify
  alias Plug.Conn

  @chain_id "1"
  @address "0x0000000000000000000000000000000000000abc"

  @metadata %{
    "compiler" => %{"version" => "0.8.19+commit.7dd6d404"},
    "output" => %{"abi" => [%{"type" => "constructor", "inputs" => []}]},
    "settings" => %{
      "compilationTarget" => %{"contracts/Foo.sol" => "Foo"},
      "evmVersion" => "paris",
      "optimizer" => %{"enabled" => true, "runs" => 200},
      "libraries" => %{}
    }
  }

  setup do
    bypass = Bypass.open()

    previous_tesla_adapter = Application.get_env(:tesla, :adapter)
    previous_sourcify_config = Application.get_env(:explorer, Sourcify)

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    Application.put_env(:explorer, Sourcify,
      server_url: "http://localhost:#{bypass.port}",
      enabled: true,
      chain_id: @chain_id,
      repo_url: "https://repo.sourcify.dev",
      verification_poll_interval_ms: 5,
      verification_max_attempts: 5
    )

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, previous_tesla_adapter)
      Application.put_env(:explorer, Sourcify, previous_sourcify_config)
      Bypass.down(bypass)
    end)

    {:ok, bypass: bypass}
  end

  defp expect_lookup(bypass, body, status \\ 200) do
    Bypass.expect_once(bypass, "GET", "/v2/contract/#{@chain_id}/#{@address}", fn conn ->
      Conn.resp(conn, status, Utils.JSON.encode!(body))
    end)
  end

  describe "check_by_address/1" do
    test "maps exact_match to the legacy perfect status", %{bypass: bypass} do
      expect_lookup(bypass, %{"match" => "exact_match", "address" => @address, "chainId" => @chain_id})

      assert Sourcify.check_by_address(@address) == {:ok, [%{"status" => "perfect"}]}
    end

    test "maps a partial match to {:error, \"partial\"}", %{bypass: bypass} do
      expect_lookup(bypass, %{"match" => "match", "address" => @address, "chainId" => @chain_id})

      assert Sourcify.check_by_address(@address) == {:error, "partial"}
    end

    test "treats match: null as not verified", %{bypass: bypass} do
      expect_lookup(bypass, %{"match" => nil, "address" => @address, "chainId" => @chain_id})

      assert Sourcify.check_by_address(@address) == {:error, "Contract is not verified"}
    end

    test "treats 404 as not verified", %{bypass: bypass} do
      expect_lookup(bypass, %{"customCode" => "not_found"}, 404)

      assert Sourcify.check_by_address(@address) == {:error, "Contract is not verified"}
    end
  end

  describe "check_by_address_any/1" do
    test "returns the reconstructed legacy file list for a full match", %{bypass: bypass} do
      expect_lookup(bypass, %{
        "match" => "exact_match",
        "sources" => %{"contracts/Foo.sol" => "contract Foo {}"},
        "metadata" => @metadata
      })

      assert {:ok, "full", file_list} = Sourcify.check_by_address_any(@address)

      metadata_file = Enum.find(file_list, &(&1["name"] == "metadata.json"))
      assert metadata_file
      # metadata content must be a JSON string so downstream parsing can decode it
      assert {:ok, _} = Utils.JSON.decode(metadata_file["content"])

      source_file = Enum.find(file_list, &(&1["name"] == "Foo.sol"))
      assert source_file["path"] == "contracts/Foo.sol"
      assert source_file["content"] == "contract Foo {}"
    end

    test "maps a partial match to the \"partial\" status", %{bypass: bypass} do
      expect_lookup(bypass, %{
        "match" => "match",
        "sources" => %{"contracts/Foo.sol" => "contract Foo {}"},
        "metadata" => @metadata
      })

      assert {:ok, "partial", _file_list} = Sourcify.check_by_address_any(@address)
    end
  end

  describe "get_metadata/1" do
    test "returns the file list for a full match", %{bypass: bypass} do
      expect_lookup(bypass, %{
        "match" => "exact_match",
        "sources" => %{"contracts/Foo.sol" => "contract Foo {}"},
        "metadata" => @metadata
      })

      assert {:ok, file_list} = Sourcify.get_metadata(@address)
      assert Enum.any?(file_list, &(&1["name"] == "metadata.json"))
    end

    test "errors on a partial match (v1 files endpoint was full-match only)", %{bypass: bypass} do
      expect_lookup(bypass, %{"match" => "match", "sources" => %{}, "metadata" => @metadata})

      assert {:error, %{"error" => _}} = Sourcify.get_metadata(@address)
    end
  end

  describe "parse_params_from_sourcify/2 with a reconstructed v2 file list" do
    test "builds secondary sources with a correct relative file name", %{bypass: bypass} do
      expect_lookup(bypass, %{
        "match" => "exact_match",
        "sources" => %{
          "contracts/Foo.sol" => "contract Foo {}",
          "contracts/Lib.sol" => "library Lib {}"
        },
        "metadata" => @metadata
      })

      {:ok, file_list} = Sourcify.get_metadata(@address)

      params = Sourcify.parse_params_from_sourcify(@address, file_list)

      assert %{"secondary_sources" => [secondary], "params_to_publish" => params_to_publish} = params
      # regression: v2 source paths are relative, so the name must not collapse to "/"
      assert secondary["file_name"] == "/contracts/Lib.sol"
      assert params_to_publish["contract_source_code"] == "contract Foo {}"
      assert params_to_publish["verified_via_sourcify"] == true
    end
  end

  describe "verify_via_sourcify_server/2" do
    test "submits metadata verification and polls until success", %{bypass: bypass} do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/v2/verify/metadata/" <> _rest} ->
            Conn.resp(conn, 202, Utils.JSON.encode!(%{"verificationId" => "job-1"}))

          {"GET", "/v2/verify/job-1"} ->
            count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

            if count == 0 do
              Conn.resp(conn, 200, Utils.JSON.encode!(%{"isJobCompleted" => false}))
            else
              Conn.resp(
                conn,
                200,
                Utils.JSON.encode!(%{"isJobCompleted" => true, "contract" => %{"match" => "exact_match"}})
              )
            end
        end
      end)

      files = %{"metadata.json" => Utils.JSON.encode!(@metadata), "contracts/Foo.sol" => "contract Foo {}"}

      assert {:ok, %{"isJobCompleted" => true}} = Sourcify.verify_via_sourcify_server(@address, files)
    end

    test "returns an error when the job completes with an error", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/v2/verify/metadata/" <> _rest} ->
            Conn.resp(conn, 202, Utils.JSON.encode!(%{"verificationId" => "job-2"}))

          {"GET", "/v2/verify/job-2"} ->
            Conn.resp(
              conn,
              200,
              Utils.JSON.encode!(%{
                "isJobCompleted" => true,
                "error" => %{"message" => "compilation failed"}
              })
            )
        end
      end)

      files = %{"metadata.json" => Utils.JSON.encode!(@metadata), "contracts/Foo.sol" => "contract Foo {}"}

      assert Sourcify.verify_via_sourcify_server(@address, files) == {:error, "compilation failed"}
    end

    test "returns an error when the job completes without a contract match", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/v2/verify/metadata/" <> _rest} ->
            Conn.resp(conn, 202, Utils.JSON.encode!(%{"verificationId" => "job-4"}))

          {"GET", "/v2/verify/job-4"} ->
            Conn.resp(
              conn,
              200,
              Utils.JSON.encode!(%{"isJobCompleted" => true, "contract" => %{"match" => nil}})
            )
        end
      end)

      files = %{"metadata.json" => Utils.JSON.encode!(@metadata), "contracts/Foo.sol" => "contract Foo {}"}

      assert Sourcify.verify_via_sourcify_server(@address, files) ==
               {:error, Sourcify.failed_verification_message()}
    end

    test "times out when the job never completes", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        case {conn.method, conn.request_path} do
          {"POST", "/v2/verify/metadata/" <> _rest} ->
            Conn.resp(conn, 202, Utils.JSON.encode!(%{"verificationId" => "job-3"}))

          {"GET", "/v2/verify/job-3"} ->
            Conn.resp(conn, 200, Utils.JSON.encode!(%{"isJobCompleted" => false}))
        end
      end)

      files = %{"metadata.json" => Utils.JSON.encode!(@metadata), "contracts/Foo.sol" => "contract Foo {}"}

      assert Sourcify.verify_via_sourcify_server(@address, files) == {:error, "Sourcify verification timed out"}
    end

    test "returns the no-metadata error when metadata.json is missing" do
      files = %{"contracts/Foo.sol" => "contract Foo {}"}

      assert Sourcify.verify_via_sourcify_server(@address, files) ==
               {:error, Sourcify.no_metadata_message()}
    end
  end
end
