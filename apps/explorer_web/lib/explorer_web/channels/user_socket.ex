defmodule ExplorerWeb.UserSocket do
  use Phoenix.Socket

  channel("addresses:*", ExplorerWeb.AddressChannel)
  channel("transactions:*", ExplorerWeb.TransactionChannel)

  transport(:websocket, Phoenix.Transports.WebSocket, timeout: 45_000)
  # transport :longpoll, Phoenix.Transports.LongPoll

  def connect(%{"locale" => locale}, socket) do
    {:ok, assign(socket, :locale, locale)}
  end

  def id(_socket), do: nil
end
