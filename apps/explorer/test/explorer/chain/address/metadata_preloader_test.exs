# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Address.MetadataPreloaderTest do
  use ExUnit.Case, async: false

  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.MetadataPreloader
  alias Explorer.MicroserviceInterfaces.{BENS, Metadata}
  alias Plug.Conn

  @address_hash_string "0x000000000000000000000000000000000000000a"
  @ens_name "test.eth"
  @metadata_tag %{"name" => "Test", "tagType" => "name", "meta" => %{}}

  setup do
    bypass = Bypass.open()
    old_bens_env = Application.get_env(:explorer, BENS, [])
    old_metadata_env = Application.get_env(:explorer, Metadata, [])
    old_chain_id = Application.get_env(:block_scout_web, :chain_id)

    Application.put_env(:block_scout_web, :chain_id, 1)

    Application.put_env(
      :explorer,
      BENS,
      Keyword.merge(old_bens_env || [],
        service_url: "http://localhost:#{bypass.port}",
        enabled: true,
        # legacy, chain-id-based URLs, so the expected paths are deterministic
        protocols: []
      )
    )

    Application.put_env(
      :explorer,
      Metadata,
      Keyword.merge(old_metadata_env || [], service_url: "http://localhost:#{bypass.port}", enabled: true)
    )

    on_exit(fn ->
      Bypass.down(bypass)
      Application.put_env(:explorer, BENS, old_bens_env)
      Application.put_env(:explorer, Metadata, old_metadata_env)
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
    end)

    {:ok, bypass: bypass}
  end

  describe "maybe_preload_ens_and_metadata/2" do
    test "preloads ENS names and metadata from both microservices", %{bypass: bypass} do
      expect_both_microservices(bypass)

      [address] = MetadataPreloader.maybe_preload_ens_and_metadata([address()])

      assert address.ens_domain_name == @ens_name
      assert address.metadata == %{"tags" => [@metadata_tag]}
    end

    test "preloads metadata when the ENS preload is disabled for the entity kind", %{bypass: bypass} do
      Application.put_env(
        :explorer,
        BENS,
        Keyword.put(Application.get_env(:explorer, BENS), :disable_transactions_bens_preload, true)
      )

      expect_both_microservices(bypass)

      [address] = MetadataPreloader.maybe_preload_ens_and_metadata([address()], :transactions)

      assert address.ens_domain_name == nil
      assert address.metadata == %{"tags" => [@metadata_tag]}
    end

    test "preloads ENS names when the metadata microservice fails", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        case conn.request_path do
          "/api/v1/1/addresses:batch_resolve_names" ->
            Conn.resp(conn, 200, Jason.encode!(%{"names" => %{checksummed_address_hash() => @ens_name}}))

          _metadata_path ->
            Conn.resp(conn, 500, "")
        end
      end)

      [address] = MetadataPreloader.maybe_preload_ens_and_metadata([address()])

      assert address.ens_domain_name == @ens_name
      assert address.metadata == nil
    end

    test "returns a single entity as-is, not wrapped in a list", %{bypass: bypass} do
      expect_both_microservices(bypass)

      address = MetadataPreloader.maybe_preload_ens_and_metadata(address())

      assert %Address{ens_domain_name: @ens_name} = address
    end

    test "skips both microservices when there are no address hashes" do
      # any request to the bypass would fail the test, since nothing is expected
      assert MetadataPreloader.maybe_preload_ens_and_metadata([]) == []
    end
  end

  describe "maybe_preload_selected_meta/2" do
    test "queries both microservices concurrently when both fields are requested", %{bypass: bypass} do
      expect_both_microservices(bypass)

      address = MetadataPreloader.maybe_preload_selected_meta(address(), [:ens_domain_name, :metadata])

      assert address.ens_domain_name == @ens_name
      assert address.metadata == %{"tags" => [@metadata_tag]}
    end

    test "queries only BENS when just the ENS field is requested", %{bypass: bypass} do
      expect_only(bypass, "/api/v1/1/addresses:batch_resolve_names")

      address = MetadataPreloader.maybe_preload_selected_meta(address(), [:ens_domain_name])

      assert address.ens_domain_name == @ens_name
      assert address.metadata == nil
    end

    test "queries only Metadata when just the metadata field is requested", %{bypass: bypass} do
      expect_only(bypass, "/api/v1/metadata")

      address = MetadataPreloader.maybe_preload_selected_meta(address(), [:metadata])

      assert address.ens_domain_name == nil
      assert address.metadata == %{"tags" => [@metadata_tag]}
    end

    test "queries nothing when no field is requested" do
      # any request to the bypass would fail the test, since nothing is expected
      assert MetadataPreloader.maybe_preload_selected_meta(address(), []) == address()
    end

    test "ignores DISABLE_TRANSACTIONS_BENS_PRELOAD, since the caller opted in explicitly", %{bypass: bypass} do
      Application.put_env(
        :explorer,
        BENS,
        Keyword.put(Application.get_env(:explorer, BENS), :disable_transactions_bens_preload, true)
      )

      expect_only(bypass, "/api/v1/1/addresses:batch_resolve_names")

      address = MetadataPreloader.maybe_preload_selected_meta(address(), [:ens_domain_name])

      assert address.ens_domain_name == @ens_name
    end
  end

  defp address do
    {:ok, hash} = Chain.string_to_address_hash(@address_hash_string)
    %Address{hash: hash}
  end

  defp checksummed_address_hash, do: Address.checksum(@address_hash_string)

  # fails the test if any path other than `expected_path` is requested
  defp expect_only(bypass, expected_path) do
    Bypass.expect(bypass, fn %{request_path: ^expected_path} = conn ->
      Conn.resp(conn, 200, response_body(expected_path))
    end)
  end

  defp response_body("/api/v1/1/addresses:batch_resolve_names") do
    Jason.encode!(%{"names" => %{checksummed_address_hash() => @ens_name}})
  end

  defp response_body("/api/v1/metadata") do
    Jason.encode!(%{
      "addresses" => %{
        checksummed_address_hash() => %{"tags" => [Map.put(@metadata_tag, "meta", Jason.encode!(%{}))]}
      }
    })
  end

  defp expect_both_microservices(bypass) do
    Bypass.expect(bypass, fn conn ->
      Conn.resp(conn, 200, response_body(conn.request_path))
    end)
  end
end
