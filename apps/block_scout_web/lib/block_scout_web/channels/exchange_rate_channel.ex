defmodule BlockScoutWeb.ExchangeRateChannel do
  @moduledoc """
  Establishes pub/sub channel for exchange rate live updates.
  """
  use BlockScoutWeb, :channel

  def join("exchange_rate_old:new_rate", _params, socket) do
    {:ok, %{}, socket}
  end
end
