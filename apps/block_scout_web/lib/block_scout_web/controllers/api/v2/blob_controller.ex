defmodule BlockScoutWeb.API.V2.BlobController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.Beacon.Reader
  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/blobs/:blob_hash_param` endpoint.
  """
  @spec blob(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def blob(conn, %{"blob_hash_param" => blob_hash_string} = _params) do
    with {:format, {:ok, blob_hash}} <- {:format, Chain.string_to_transaction_hash(blob_hash_string)} do
      transaction_hashes = Reader.blob_hash_to_transactions(blob_hash, api?: true)

      case Reader.blob(blob_hash, api?: true) do
        {:ok, blob} ->
          conn
          |> put_status(200)
          |> render(:blob, %{blob: blob, transaction_hashes: transaction_hashes})

        {:error, :not_found} ->
          conn
          |> put_status(200)
          |> render(:blob, %{transaction_hashes: transaction_hashes})
      end
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/blobs` endpoint.
  """
  @spec blobs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def blobs(conn, params) do
    {blobs_transactions, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.blobs_transactions()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, blobs_transactions, params)

    conn
    |> put_status(200)
    |> render(:blobs_transactions, %{
      blobs_transactions: blobs_transactions,
      next_page_params: next_page_params
    })
  end
end
