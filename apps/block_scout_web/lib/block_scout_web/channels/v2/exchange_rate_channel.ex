defmodule BlockScoutWeb.V2.ExchangeRateChannel do
  @moduledoc """
  Establishes pub/sub channel for exchange rate live updates for API V2.
  """
  use BlockScoutWeb, :channel

  def join("exchange_rate:new_rate", _params, socket) do
    {:ok, %{}, socket}
  end
end
