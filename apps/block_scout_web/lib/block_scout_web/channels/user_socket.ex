defmodule BlockScoutWeb.UserSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: BlockScoutWeb.GraphQL.Schema

  channel("addresses_old:*", BlockScoutWeb.AddressChannel)
  channel("blocks_old:*", BlockScoutWeb.BlockChannel)
  channel("exchange_rate_old:*", BlockScoutWeb.ExchangeRateChannel)
  channel("rewards_old:*", BlockScoutWeb.RewardChannel)
  channel("transactions_old:*", BlockScoutWeb.TransactionChannel)
  channel("tokens_old:*", BlockScoutWeb.TokenChannel)
  channel("token_instances_old:*", BlockScoutWeb.TokenInstanceChannel)

  def connect(%{"locale" => locale}, socket) do
    {:ok, assign(socket, :locale, locale)}
  end

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
