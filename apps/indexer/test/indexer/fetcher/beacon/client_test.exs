# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Beacon.ClientTest do
  use ExUnit.Case, async: true

  alias Indexer.Fetcher.Beacon.Client

  @beacon_rpc "http://localhost:5052"

  describe "blobs_url/2" do
    test "builds the URL without filter" do
      assert Client.blobs_url(11_296_783) == @beacon_rpc <> "/eth/v1/beacon/blobs/11296783"
      assert Client.blobs_url(11_296_783, []) == @beacon_rpc <> "/eth/v1/beacon/blobs/11296783"
    end

    test "builds the URL with versioned hashes filter" do
      hash_a = "0x01" <> String.duplicate("aa", 31)
      hash_b = "0x01" <> String.duplicate("bb", 31)

      assert Client.blobs_url(11_296_783, [hash_a]) ==
               @beacon_rpc <> "/eth/v1/beacon/blobs/11296783?versioned_hashes=" <> hash_a

      assert Client.blobs_url(11_296_783, [hash_a, hash_b]) ==
               @beacon_rpc <> "/eth/v1/beacon/blobs/11296783?versioned_hashes=" <> hash_a <> "," <> hash_b
    end
  end

  describe "block_url/1" do
    test "builds the v2 blocks URL" do
      assert Client.block_url(11_296_783) == @beacon_rpc <> "/eth/v2/beacon/blocks/11296783"
    end
  end

  describe "blob_sidecars_url/1" do
    test "builds the blob_sidecars URL" do
      assert Client.blob_sidecars_url(11_296_783) == @beacon_rpc <> "/eth/v1/beacon/blob_sidecars/11296783"
    end
  end

  describe "blob_from_blobs_item/1" do
    test "accepts plain hex string and wrapped forms" do
      blob = "0x" <> String.duplicate("01", 32)

      assert Client.blob_from_blobs_item(blob) == {:ok, blob}
      assert Client.blob_from_blobs_item(%{"blob" => blob}) == {:ok, blob}
    end

    test "returns error for malformed items" do
      assert Client.blob_from_blobs_item(%{"index" => "0"}) == {:error, :malformed_blobs_item}
      assert Client.blob_from_blobs_item(%{"blob" => 123}) == {:error, :malformed_blobs_item}
      assert Client.blob_from_blobs_item(nil) == {:error, :malformed_blobs_item}
      assert Client.blob_from_blobs_item(42) == {:error, :malformed_blobs_item}
    end
  end

  describe "extract_blob_kzg_commitments/1" do
    test "takes commitments from the execution payload bid of a Gloas block body" do
      commitments = ["0x" <> String.duplicate("aa", 48), "0x" <> String.duplicate("bb", 48)]

      body = %{
        "graffiti" => "0x",
        "signed_execution_payload_bid" => %{
          "message" => %{"blob_kzg_commitments" => commitments},
          "signature" => "0x"
        }
      }

      assert {:ok, ^commitments} = Client.extract_blob_kzg_commitments(body)
    end

    test "takes commitments from the body of a pre-Gloas block" do
      commitments = ["0x" <> String.duplicate("aa", 48)]

      body = %{
        "graffiti" => "0x",
        "execution_payload" => %{},
        "blob_kzg_commitments" => commitments
      }

      assert {:ok, ^commitments} = Client.extract_blob_kzg_commitments(body)
    end

    test "returns empty list for a block without blobs" do
      assert {:ok, []} = Client.extract_blob_kzg_commitments(%{"blob_kzg_commitments" => []})

      assert {:ok, []} =
               Client.extract_blob_kzg_commitments(%{
                 "signed_execution_payload_bid" => %{"message" => %{"blob_kzg_commitments" => []}}
               })
    end

    test "returns error for a pre-Deneb block body" do
      assert {:error, :blob_kzg_commitments_not_found} =
               Client.extract_blob_kzg_commitments(%{"graffiti" => "0x", "execution_payload" => %{}})
    end
  end
end
