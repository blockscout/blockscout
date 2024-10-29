defmodule BlockScoutWeb.UserSocketV2 do
  @moduledoc """
    Module to distinct new and old UI websocket connections
  """
  use Phoenix.Socket

  channel("addresses:*", BlockScoutWeb.AddressChannel)
  channel("blocks:*", BlockScoutWeb.BlockChannel)
  channel("exchange_rate:*", BlockScoutWeb.ExchangeRateChannel)
  channel("rewards:*", BlockScoutWeb.RewardChannel)
  channel("transactions:*", BlockScoutWeb.TransactionChannel)
  channel("tokens:*", BlockScoutWeb.TokenChannel)
  channel("token_instances:*", BlockScoutWeb.TokenInstanceChannel)
  channel("zkevm_batches:*", BlockScoutWeb.PolygonZkevmConfirmedBatchChannel)

  case Application.compile_env(:explorer, :chain_type) do
    :arbitrum -> channel("arbitrum:*", BlockScoutWeb.ArbitrumChannel)
    :optimism -> channel("optimism:*", BlockScoutWeb.OptimismChannel)
    _ -> nil
  end

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
