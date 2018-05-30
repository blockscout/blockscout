defmodule ExplorerWeb.AddressQRCodeController do
  use ExplorerWeb, :controller

  def index(conn, %{"address_id" => id}) do
    send_download(conn, {:binary, QRCode.to_png(id)}, "content-type": "image/png", filename: "#{id}.png")
  end
end
