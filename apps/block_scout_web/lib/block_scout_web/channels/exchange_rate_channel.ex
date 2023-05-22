defmodule BlockScoutWeb.ExchangeRateChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates.
  """
  use BlockScoutWeb, :channel

  intercept(["new_rate"])

  def join("exchange_rate:new_rate", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "new_rate",
        %{exchange_rate: exchange_rate, market_history_data: market_history_data},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "new_rate", %{
      exchange_rate: exchange_rate.usd_value,
      available_supply: exchange_rate.available_supply,
      chart_data: market_history_data
    })

    {:noreply, socket}
  end

  def handle_out("new_rate", %{exchange_rate: exchange_rate, market_history_data: market_history_data}, socket) do
    push(socket, "new_rate", %{
      exchange_rate: exchange_rate,
      market_history_data: market_history_data
    })

    {:noreply, socket}
  end
end
