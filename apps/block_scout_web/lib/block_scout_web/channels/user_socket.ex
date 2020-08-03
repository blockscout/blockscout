defmodule BlockScoutWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: BlockScoutWeb.Schema

  channel("addresses:*", BlockScoutWeb.AddressChannel)
  channel("blocks:*", BlockScoutWeb.BlockChannel)
  channel("exchange_rate:*", BlockScoutWeb.ExchangeRateChannel)
  channel("rewards:*", BlockScoutWeb.RewardChannel)
  channel("transactions:*", BlockScoutWeb.TransactionChannel)
  channel("tokens:*", BlockScoutWeb.TokenChannel)

  def connect(%{"locale" => locale}, socket) do
    {:ok, assign(socket, :locale, locale)}
  end

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
