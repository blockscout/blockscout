defmodule BlockScoutWeb.UserSocketV2 do
  use Phoenix.Socket

  channel("addresses:*", BlockScoutWeb.AddressChannel)
  channel("blocks:*", BlockScoutWeb.BlockChannel)
  channel("exchange_rate:*", BlockScoutWeb.ExchangeRateChannel)
  channel("rewards:*", BlockScoutWeb.RewardChannel)
  channel("transactions:*", BlockScoutWeb.TransactionChannel)
  channel("tokens:*", BlockScoutWeb.TokenChannel)

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
