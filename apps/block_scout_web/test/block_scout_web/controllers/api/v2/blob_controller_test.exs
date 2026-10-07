# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.BlobControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :ethereum do
    describe "/blobs/{blob_hash_param}" do
      test "returns blob with KZG proof", %{conn: conn} do
        blob = insert(:blob)
        transaction = insert(:transaction, type: 3) |> with_block()
        insert(:blob_transaction, hash: transaction.hash, blob_versioned_hashes: [blob.hash])

        request = get(conn, "/api/v2/blobs/#{blob.hash}")
        assert response = json_response(request, 200)

        assert response["hash"] == to_string(blob.hash)
        assert response["blob_data"] == to_string(blob.blob_data)
        assert response["kzg_commitment"] == to_string(blob.kzg_commitment)
        assert response["kzg_proof"] == to_string(blob.kzg_proof)

        assert response["transaction_hashes"] == [
                 %{"block_consensus" => true, "transaction_hash" => to_string(transaction.hash)}
               ]
      end

      test "returns blob without KZG proof (fetched via /eth/v1/beacon/blobs endpoint)", %{conn: conn} do
        blob = insert(:blob, kzg_proof: nil)

        request = get(conn, "/api/v2/blobs/#{blob.hash}")
        assert response = json_response(request, 200)

        assert response["hash"] == to_string(blob.hash)
        assert response["kzg_commitment"] == to_string(blob.kzg_commitment)
        assert is_nil(response["kzg_proof"])
      end

      test "returns 404 for unknown blob", %{conn: conn} do
        blob = build(:blob)

        request = get(conn, "/api/v2/blobs/#{blob.hash}")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end
    end
  end
end
