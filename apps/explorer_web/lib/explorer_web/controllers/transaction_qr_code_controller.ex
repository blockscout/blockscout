defmodule ExplorerWeb.TransactionQRCodeController do
  use ExplorerWeb, :controller

  alias Explorer.Chain.Hash.Full

  def index(conn, %{"transaction_id" => id}) do
    case Full.cast(id) do
      {:ok, _} ->
        send_download(conn, {:binary, QRCode.to_png(id)}, "content-type": "image/png", filename: "#{id}.png")

      _ ->
        send_resp(conn, :not_found, "")
    end
  end
end
