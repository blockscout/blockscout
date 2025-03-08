defmodule BlockScoutWeb.ExchangeRateChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates.
  """
  use BlockScoutWeb, :channel

  def join("exchange_rate:new_rate", _params, socket) do
    {:ok, %{}, socket}
  end
end
