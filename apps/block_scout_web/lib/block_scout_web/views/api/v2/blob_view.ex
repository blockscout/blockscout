defmodule BlockScoutWeb.API.V2.BlobView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Beacon.Blob

  def render("blob.json", %{blob: blob, transaction_hashes: transaction_hashes}) do
    prepare_blob(blob) |> Map.put("transaction_hashes", transaction_hashes)
  end

  def render("blob.json", %{transaction_hashes: transaction_hashes}) do
    %{"transaction_hashes" => transaction_hashes}
  end

  def render("blobs.json", %{blobs: blobs}) do
    %{"items" => Enum.map(blobs, &prepare_blob(&1))}
  end

  def render("blobs_transactions.json", %{blobs_transactions: blobs_transactions, next_page_params: next_page_params}) do
    %{"items" => Enum.map(blobs_transactions, &prepare_blob_transaction(&1)), "next_page_params" => next_page_params}
  end

  @spec prepare_blob(Blob.t()) :: map()
  def prepare_blob(blob) do
    %{
      "hash" => blob.hash,
      "blob_data" => blob.blob_data,
      "kzg_commitment" => blob.kzg_commitment,
      "kzg_proof" => blob.kzg_proof
    }
  end

  @spec prepare_blob_transaction(%{block_number: non_neg_integer(), blob_hashes: [Hash.t()], transaction_hash: Hash.t()}) ::
          map()
  def prepare_blob_transaction(blob_transaction) do
    %{
      "block_number" => blob_transaction.block_number,
      "blob_hashes" => blob_transaction.blob_hashes,
      "transaction_hash" => blob_transaction.transaction_hash
    }
  end
end
