defmodule BlockScoutWeb.API.V2.BlobView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Beacon.Blob

  def render("blob.json", %{blob: blob, transaction_hashes: transaction_hashes}) do
    blob |> prepare_blob() |> Map.put("transaction_hashes", transaction_hashes)
  end

  def render("blob.json", %{transaction_hashes: transaction_hashes}) do
    %{"transaction_hashes" => transaction_hashes}
  end

  def render("blobs.json", %{blobs: blobs}) do
    %{"items" => Enum.map(blobs, &prepare_blob(&1))}
  end

  @spec prepare_blob(Blob.t()) :: map()
  def prepare_blob(blob) do
    %{
      "hash" => blob.hash,
      "blob_data" => encode_binary(blob.blob_data),
      "kzg_commitment" => encode_binary(blob.kzg_commitment),
      "kzg_proof" => encode_binary(blob.kzg_proof)
    }
  end

  defp encode_binary(binary) do
    "0x" <> Base.encode16(binary, case: :lower)
  end
end
