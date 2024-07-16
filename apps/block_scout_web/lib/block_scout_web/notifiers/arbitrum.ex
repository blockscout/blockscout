defmodule BlockScoutWeb.Notifiers.Arbitrum do
  @moduledoc """
  Module to handle and broadcast Arbitrum related events.
  """

  alias BlockScoutWeb.API.V2.ArbitrumView
  alias BlockScoutWeb.Endpoint

  require Logger

  def handle_event({:chain_event, :new_arbitrum_batches, :realtime, batches}) do
    batches
    |> Enum.sort_by(& &1.number, :asc)
    |> Enum.each(fn batch ->
      Endpoint.broadcast("arbitrum:new_batch", "new_arbitrum_batch", %{
        batch: ArbitrumView.render_base_info_for_batch(batch)
      })
    end)
  end

  def handle_event({:chain_event, :new_messages_to_arbitrum_amount, :realtime, new_messages_amount}) do
    Endpoint.broadcast("arbitrum:new_messages_to_rollup_amount", "new_messages_to_rollup_amount", %{
      new_messages_to_rollup_amount: new_messages_amount
    })
  end

  def handle_event(event) do
    Logger.warning("Unknown broadcasted event #{inspect(event)}.")
    nil
  end
end
