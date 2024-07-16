defmodule BlockScoutWeb.API.V2.BlobView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Beacon.Blob

  def render("blob.json", %{blob: blob, transaction_hashes: transaction_hashes}) do
    blob |> prepare_blob() |> Map.put("transaction_hashes", transaction_hashes)
  end

  def render("blobs.json", %{blobs: blobs}) do
    %{"items" => Enum.map(blobs, &prepare_blob(&1))}
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
end
