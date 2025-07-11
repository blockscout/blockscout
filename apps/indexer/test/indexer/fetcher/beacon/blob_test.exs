defmodule Indexer.Fetcher.Beacon.BlobTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.Transaction
  alias Explorer.Chain.Beacon.{Blob, Reader}
  alias Indexer.Fetcher.Beacon.Blob.Supervisor, as: BlobSupervisor

  setup :verify_on_exit!
  setup :set_mox_global

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

        result_ab = """
        {
          "data": [
            {
              "index": "0",
              "blob": "#{to_string(blob_a.blob_data)}",
              "kzg_commitment": "#{to_string(blob_a.kzg_commitment)}",
              "kzg_proof": "#{to_string(blob_a.kzg_proof)}"
            },
            {
              "index": "1",
              "blob": "#{to_string(blob_b.blob_data)}",
              "kzg_commitment": "#{to_string(blob_b.kzg_commitment)}",
              "kzg_proof": "#{to_string(blob_b.kzg_proof)}"
            }
          ]
        }
        """

        result_c = """
        {
          "data": [
            {
              "index": "0",
              "blob": "#{to_string(blob_c.blob_data)}",
              "kzg_commitment": "#{to_string(blob_c.kzg_commitment)}",
              "kzg_proof": "#{to_string(blob_c.kzg_proof)}"
            }
          ]
        }
        """

        Tesla.Test.expect_tesla_call(
          times: 2,
          returns: fn %{url: url}, _opts ->
            case url do
              "http://localhost:5052/eth/v1/beacon/blob_sidecars/8269188" ->
                {:ok, %Tesla.Env{status: 200, body: result_c}}

              "http://localhost:5052/eth/v1/beacon/blob_sidecars/8269198" ->
                {:ok, %Tesla.Env{status: 200, body: result_ab}}
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

      test "fetches blobs for block timestamp" do
        {:ok, now, _} = DateTime.from_iso8601("2024-01-24 00:00:00Z")
        block_a = insert(:block, timestamp: now)

        %Blob{
          hash: blob_hash_a,
          blob_data: blob_data_a,
          kzg_commitment: kzg_commitment_a,
          kzg_proof: kzg_proof_a
        } = build(:blob)

        result_a = """
        {
          "data": [
            {
              "index": "0",
              "blob": "#{to_string(blob_data_a)}",
              "kzg_commitment": "#{to_string(kzg_commitment_a)}",
              "kzg_proof": "#{to_string(kzg_proof_a)}"
            }
          ]
        }
        """

        Tesla.Test.expect_tesla_call(
          times: 1,
          returns: fn %{url: "http://localhost:5052/eth/v1/beacon/blob_sidecars/8269198"}, _opts ->
            {:ok,
             %Tesla.Env{
               status: 200,
               body: result_a
             }}
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
    end
  end
end
