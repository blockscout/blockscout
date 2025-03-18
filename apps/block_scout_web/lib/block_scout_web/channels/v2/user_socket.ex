defmodule BlockScoutWeb.V2.UserSocket do
  @moduledoc """
    Module to distinct new and old UI websocket connections
  """
  use Phoenix.Socket
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  channel("addresses:*", BlockScoutWeb.V2.AddressChannel)
  channel("blocks:*", BlockScoutWeb.V2.BlockChannel)
  channel("exchange_rate:*", BlockScoutWeb.V2.ExchangeRateChannel)
  channel("rewards:*", BlockScoutWeb.V2.RewardChannel)
  channel("transactions:*", BlockScoutWeb.V2.TransactionChannel)
  channel("tokens:*", BlockScoutWeb.V2.TokenChannel)
  channel("token_instances:*", BlockScoutWeb.TokenInstanceChannel)
  channel("zkevm_batches:*", BlockScoutWeb.V2.PolygonZkevmConfirmedBatchChannel)

  case @chain_type do
    :arbitrum -> channel("arbitrum:*", BlockScoutWeb.ArbitrumChannel)
    # todo: change `optimism*"` to `optimism:*` after the deprecated `optimism_deposits:new_deposits` topic is removed
    :optimism -> channel("optimism*", BlockScoutWeb.OptimismChannel)
    _ -> nil
  end

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
