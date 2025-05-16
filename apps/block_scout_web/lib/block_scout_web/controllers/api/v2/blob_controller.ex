defmodule BlockScoutWeb.API.V2.BlobController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Beacon.{Blob, Reader}

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/blobs/:blob_hash_param` endpoint.
  """
  @spec blob(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def blob(conn, %{"blob_hash_param" => blob_hash_string} = _params) do
    with {:format, {:ok, blob_hash}} <- {:format, Chain.string_to_full_hash(blob_hash_string)} do
      transaction_hashes = Reader.blob_hash_to_transactions(blob_hash, api?: true)

      {status, blob} =
        case Reader.blob(blob_hash, true, api?: true) do
          {:ok, blob} -> {:ok, blob}
          {:error, :not_found} -> {:pending, %Blob{hash: blob_hash}}
        end

      if Enum.empty?(transaction_hashes) and status == :pending do
        {:error, :not_found}
      else
        conn
        |> put_status(200)
        |> render(:blob, %{blob: blob, transaction_hashes: transaction_hashes})
      end
    end
  end
end
