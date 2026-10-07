# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Helper.BeaconBlobTest do
  use ExUnit.Case, async: false

  import Explorer.Helper, only: [hash_to_binary: 1]

  alias Explorer.Chain.Beacon.Blob, as: BeaconBlob
  alias Explorer.Chain.Hash
  alias Indexer.Helper

  @sepolia_chain_id 11_155_111
  # Sepolia reference slot 4_400_000 corresponds to timestamp 1_708_533_600 (see `Indexer.Helper`)
  @slot 4_400_010
  @block_timestamp DateTime.from_unix!(1_708_533_600 + 10 * 12)

  @kzg_commitment "0x" <> String.duplicate("ab", 48)
  @other_kzg_commitment "0x" <> String.duplicate("cd", 48)
  @blob "0x" <> String.duplicate("01", 64)
  @other_blob "0x" <> String.duplicate("02", 64)

  setup do
    bypass = Bypass.open()

    initial_env = Application.get_env(:indexer, Indexer.Fetcher.Beacon)
    Application.put_env(:indexer, Indexer.Fetcher.Beacon, beacon_rpc: "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.Beacon, initial_env)
      Bypass.down(bypass)
    end)

    {:ok, bypass: bypass, blob_hash: versioned_hash(@kzg_commitment)}
  end

  describe "get_eip4844_blob_from_beacon_node/3" do
    test "takes the blob from the blobs endpoint filtered by versioned hash", %{bypass: bypass, blob_hash: blob_hash} do
      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blobs/#{@slot}", fn conn ->
        assert conn.query_string == "versioned_hashes=" <> blob_hash

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"execution_optimistic" => false, "finalized" => true, "data" => [@blob]})
        )
      end)

      assert Helper.get_eip4844_blob_from_beacon_node(blob_hash, @block_timestamp, @sepolia_chain_id) ==
               hash_to_binary(@blob)
    end

    test "falls back to blob_sidecars endpoint without retries when blobs endpoint responds with 400", %{
      bypass: bypass,
      blob_hash: blob_hash
    } do
      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blobs/#{@slot}", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"code":400,"message":"BAD_REQUEST: block is pre-Deneb and has no blobs"}))
      end)

      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blob_sidecars/#{@slot}", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => [
              %{"index" => "0", "blob" => @other_blob, "kzg_commitment" => @other_kzg_commitment, "kzg_proof" => "0x"},
              %{"index" => "1", "blob" => @blob, "kzg_commitment" => @kzg_commitment, "kzg_proof" => "0x"}
            ]
          })
        )
      end)

      {elapsed_microseconds, result} =
        :timer.tc(fn -> Helper.get_eip4844_blob_from_beacon_node(blob_hash, @block_timestamp, @sepolia_chain_id) end)

      assert result == hash_to_binary(@blob)
      # the first retry sleep of `Indexer.Helper.http_get_request/4` is 3 seconds, so the 400 response wasn't retried
      assert elapsed_microseconds < 3_000_000
    end

    test "falls back to blob_sidecars endpoint without retries when blobs endpoint responds with 405", %{
      bypass: bypass,
      blob_hash: blob_hash
    } do
      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blobs/#{@slot}", fn conn ->
        Plug.Conn.resp(conn, 405, ~s({"code":405,"message":"Method Not Allowed"}))
      end)

      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blob_sidecars/#{@slot}", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => [%{"index" => "0", "blob" => @blob, "kzg_commitment" => @kzg_commitment, "kzg_proof" => "0x"}]
          })
        )
      end)

      {elapsed_microseconds, result} =
        :timer.tc(fn -> Helper.get_eip4844_blob_from_beacon_node(blob_hash, @block_timestamp, @sepolia_chain_id) end)

      assert result == hash_to_binary(@blob)
      assert elapsed_microseconds < 3_000_000
    end

    test "falls back to blob_sidecars endpoint when the blobs endpoint doesn't know the versioned hash", %{
      bypass: bypass,
      blob_hash: blob_hash
    } do
      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blobs/#{@slot}", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"execution_optimistic" => false, "finalized" => true, "data" => []}))
      end)

      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blob_sidecars/#{@slot}", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => [%{"index" => "0", "blob" => @blob, "kzg_commitment" => @kzg_commitment, "kzg_proof" => "0x"}]
          })
        )
      end)

      assert Helper.get_eip4844_blob_from_beacon_node(blob_hash, @block_timestamp, @sepolia_chain_id) ==
               hash_to_binary(@blob)
    end

    test "returns nil when both endpoints fail", %{bypass: bypass, blob_hash: blob_hash} do
      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blobs/#{@slot}", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"code":404,"message":"Not Found"}))
      end)

      Bypass.expect_once(bypass, "GET", "/eth/v1/beacon/blob_sidecars/#{@slot}", fn conn ->
        Plug.Conn.resp(conn, 400, ~s({"code":400,"message":"BAD_REQUEST: block is pre-Deneb and has no blobs"}))
      end)

      assert is_nil(Helper.get_eip4844_blob_from_beacon_node(blob_hash, @block_timestamp, @sepolia_chain_id))
    end
  end

  defp versioned_hash(kzg_commitment) do
    kzg_commitment
    |> hash_to_binary()
    |> BeaconBlob.hash()
    |> Hash.to_string()
  end
end
