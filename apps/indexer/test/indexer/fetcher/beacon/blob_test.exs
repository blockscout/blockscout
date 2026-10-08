# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Beacon.BlobTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.Transaction
  alias Explorer.Chain.Beacon.{Blob, Reader}
  alias Indexer.Fetcher.Beacon.Blob.Supervisor, as: BlobSupervisor

  setup :verify_on_exit!
  setup :set_mox_global

  @beacon_rpc "http://localhost:5052"

  if Application.compile_env(:explorer, :chain_type) == :ethereum do
    describe "init/1" do
      setup do
        initial_env = Application.get_env(:indexer, BlobSupervisor)
        Application.put_env(:indexer, BlobSupervisor, initial_env |> Keyword.put(:disabled?, false))

        on_exit(fn ->
          Application.put_env(:indexer, BlobSupervisor, initial_env)
        end)
      end

      test "fetches all missed blob transactions" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)
        block_b = insert(:block, timestamp: now |> Timex.shift(seconds: -120))
        block_c = insert(:block, timestamp: now |> Timex.shift(seconds: -240))

        blob_a = build(:blob)
        blob_b = build(:blob)
        blob_c = build(:blob)
        blob_d = insert(:blob)

        %Transaction{hash: transaction_a_hash} = insert(:transaction, type: 3) |> with_block(block_a)
        %Transaction{hash: transaction_b_hash} = insert(:transaction, type: 3) |> with_block(block_b)
        %Transaction{hash: transaction_c_hash} = insert(:transaction, type: 3) |> with_block(block_c)

        insert(:blob_transaction, hash: transaction_a_hash, blob_versioned_hashes: [blob_a.hash, blob_b.hash])
        insert(:blob_transaction, hash: transaction_b_hash, blob_versioned_hashes: [blob_c.hash])
        insert(:blob_transaction, hash: transaction_c_hash, blob_versioned_hashes: [blob_d.hash])

        assert {:error, :not_found} = Reader.blob(blob_a.hash, true)
        assert {:error, :not_found} = Reader.blob(blob_b.hash, true)
        assert {:error, :not_found} = Reader.blob(blob_c.hash, true)
        assert {:ok, _} = Reader.blob(blob_d.hash, true)

        Tesla.Test.expect_tesla_call(
          times: 4,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269188" ->
                {:ok, %Tesla.Env{status: 200, body: blobs_response([blob_c])}}

              @beacon_rpc <> "/eth/v2/beacon/blocks/8269188" ->
                {:ok, %Tesla.Env{status: 200, body: gloas_block_response([blob_c])}}

              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: blobs_response([blob_a, blob_b])}}

              @beacon_rpc <> "/eth/v2/beacon/blocks/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: gloas_block_response([blob_a, blob_b])}}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        wait_for_results(fn ->
          Repo.one!(from(blob in Blob, where: blob.hash == ^blob_a.hash))
        end)

        assert {:ok, _} = Reader.blob(blob_a.hash, true)
        assert {:ok, _} = Reader.blob(blob_b.hash, true)
        assert {:ok, _} = Reader.blob(blob_c.hash, true)
        assert {:ok, _} = Reader.blob(blob_d.hash, true)
      end
    end

    describe "async_fetch/1" do
      setup do
        initial_env = Application.get_env(:indexer, BlobSupervisor)
        Application.put_env(:indexer, BlobSupervisor, initial_env |> Keyword.put(:disabled?, false))

        on_exit(fn ->
          Application.put_env(:indexer, BlobSupervisor, initial_env)
        end)
      end

      test "fetches blobs of a Gloas block (commitments are taken from the execution payload bid)" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        %Blob{
          hash: blob_hash_a,
          blob_data: blob_data_a,
          kzg_commitment: kzg_commitment_a
        } = blob_a = build(:blob)

        Tesla.Test.expect_tesla_call(
          times: 2,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: blobs_response([blob_a])}}

              @beacon_rpc <> "/eth/v2/beacon/blocks/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: gloas_block_response([blob_a])}}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        assert :ok = Indexer.Fetcher.Beacon.Blob.async_fetch([block_a.timestamp], false)

        wait_for_results(fn ->
          Repo.one!(from(blob in Blob, where: blob.hash == ^blob_hash_a))
        end)

        assert {:ok, blob} = Reader.blob(blob_hash_a, true)

        assert %{
                 hash: ^blob_hash_a,
                 blob_data: ^blob_data_a,
                 kzg_commitment: ^kzg_commitment_a,
                 kzg_proof: nil
               } = blob
      end

      test "fetches blobs of a pre-Gloas block (commitments are taken from the block body)" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        blob_a = build(:blob)
        blob_b = build(:blob)

        Tesla.Test.expect_tesla_call(
          times: 2,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: blobs_response([blob_a, blob_b])}}

              @beacon_rpc <> "/eth/v2/beacon/blocks/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: electra_block_response([blob_a, blob_b])}}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        assert :ok = Indexer.Fetcher.Beacon.Blob.async_fetch([block_a.timestamp], false)

        wait_for_results(fn ->
          Repo.one!(from(blob in Blob, where: blob.hash == ^blob_b.hash))
        end)

        assert {:ok, %{blob_data: blob_data_a, kzg_commitment: kzg_commitment_a, kzg_proof: nil}} =
                 Reader.blob(blob_a.hash, true)

        assert blob_data_a == blob_a.blob_data
        assert kzg_commitment_a == blob_a.kzg_commitment

        assert {:ok, %{blob_data: blob_data_b, kzg_commitment: kzg_commitment_b, kzg_proof: nil}} =
                 Reader.blob(blob_b.hash, true)

        assert blob_data_b == blob_b.blob_data
        assert kzg_commitment_b == blob_b.kzg_commitment
      end

      test "falls back to blob_sidecars endpoint when blobs endpoint is not available" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        %Blob{
          hash: blob_hash_a,
          blob_data: blob_data_a,
          kzg_commitment: kzg_commitment_a,
          kzg_proof: kzg_proof_a
        } = blob_a = build(:blob)

        Tesla.Test.expect_tesla_call(
          times: 2,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 404, body: ~s({"code":404,"message":"Not Found"})}}

              @beacon_rpc <> "/eth/v1/beacon/blob_sidecars/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: blob_sidecars_response([blob_a])}}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        assert :ok = Indexer.Fetcher.Beacon.Blob.async_fetch([block_a.timestamp], false)

        wait_for_results(fn ->
          Repo.one!(from(blob in Blob, where: blob.hash == ^blob_hash_a))
        end)

        assert {:ok, blob} = Reader.blob(blob_hash_a, true)

        assert %{
                 hash: ^blob_hash_a,
                 blob_data: ^blob_data_a,
                 kzg_commitment: ^kzg_commitment_a,
                 kzg_proof: ^kzg_proof_a
               } = blob
      end

      test "doesn't import blobs when their number differs from the number of commitments" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        blob_a = build(:blob)
        blob_b = build(:blob)

        test_pid = self()

        # the fetcher retries the slot twice before giving up (the block is older than the retry deadline)
        Tesla.Test.expect_tesla_call(
          times: 6,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: blobs_response([blob_a, blob_b])}}

              @beacon_rpc <> "/eth/v2/beacon/blocks/8269198" ->
                send(test_pid, :block_requested)
                {:ok, %Tesla.Env{status: 200, body: gloas_block_response([blob_a])}}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        assert :ok = Indexer.Fetcher.Beacon.Blob.async_fetch([block_a.timestamp], false)

        # initial attempt + 2 retries
        for _ <- 1..3 do
          assert_receive :block_requested, 10_000
        end

        assert {:error, :not_found} = Reader.blob(blob_a.hash, true)
        assert {:error, :not_found} = Reader.blob(blob_b.hash, true)
      end

      test "doesn't crash on malformed blob sidecars and retries the slot" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        blob_a = build(:blob)

        test_pid = self()

        # the fetcher retries the slot twice before giving up (the block is older than the retry deadline)
        Tesla.Test.expect_tesla_call(
          times: 6,
          returns: fn %{url: url}, _opts ->
            case url do
              @beacon_rpc <> "/eth/v1/beacon/blobs/8269198" ->
                {:ok, %Tesla.Env{status: 404, body: ~s({"code":404,"message":"Not Found"})}}

              @beacon_rpc <> "/eth/v1/beacon/blob_sidecars/8269198" ->
                send(test_pid, :sidecars_requested)

                # `kzg_commitment` is missing
                {:ok,
                 %Tesla.Env{
                   status: 200,
                   body: Jason.encode!(%{"data" => [%{"index" => "0", "blob" => to_string(blob_a.blob_data)}]})
                 }}
            end
          end
        )

        BlobSupervisor.Case.start_supervised!()

        assert :ok = Indexer.Fetcher.Beacon.Blob.async_fetch([block_a.timestamp], false)

        # initial attempt + 2 retries
        for _ <- 1..3 do
          assert_receive :sidecars_requested, 10_000
        end

        assert {:error, :not_found} = Reader.blob(blob_a.hash, true)
      end
    end
  end

  # `data` is a list of plain hex strings as per the beacon API spec
  defp blobs_response(blobs) do
    data = Enum.map(blobs, fn blob -> to_string(blob.blob_data) end)

    Jason.encode!(%{"execution_optimistic" => false, "finalized" => true, "data" => data})
  end

  defp blob_sidecars_response(blobs) do
    data =
      blobs
      |> Enum.with_index()
      |> Enum.map(fn {blob, index} ->
        %{
          "index" => to_string(index),
          "blob" => to_string(blob.blob_data),
          "kzg_commitment" => to_string(blob.kzg_commitment),
          "kzg_proof" => to_string(blob.kzg_proof)
        }
      end)

    Jason.encode!(%{"data" => data})
  end

  defp gloas_block_response(blobs) do
    commitments = Enum.map(blobs, &to_string(&1.kzg_commitment))

    Jason.encode!(%{
      "version" => "gloas",
      "execution_optimistic" => false,
      "finalized" => true,
      "data" => %{
        "message" => %{
          "slot" => "8269198",
          "body" => %{
            "graffiti" => "0x0000000000000000000000000000000000000000000000000000000000000000",
            "signed_execution_payload_bid" => %{
              "message" => %{
                "slot" => "8269198",
                "blob_kzg_commitments" => commitments
              },
              "signature" => "0x"
            }
          }
        },
        "signature" => "0x"
      }
    })
  end

  defp electra_block_response(blobs) do
    commitments = Enum.map(blobs, &to_string(&1.kzg_commitment))

    Jason.encode!(%{
      "version" => "electra",
      "execution_optimistic" => false,
      "finalized" => true,
      "data" => %{
        "message" => %{
          "slot" => "8269198",
          "body" => %{
            "graffiti" => "0x0000000000000000000000000000000000000000000000000000000000000000",
            "blob_kzg_commitments" => commitments
          }
        },
        "signature" => "0x"
      }
    })
  end
end
