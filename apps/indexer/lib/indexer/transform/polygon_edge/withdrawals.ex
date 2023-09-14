defmodule Indexer.Transform.PolygonEdge.Withdrawals do
  @moduledoc """
  Helper functions for transforming data for Polygon Edge withdrawals.
  """

  require Logger

  alias Indexer.Fetcher.PolygonEdge.Withdrawal
  alias Indexer.Helper

  @doc """
  Returns a list of withdrawals given a list of logs.
  """
  @spec parse(list()) :: list()
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :polygon_edge_withdrawals_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, Withdrawal)[:start_block_l2]),
           state_sender = Application.get_env(:indexer, Withdrawal)[:state_sender],
           true <- Helper.is_address_correct?(state_sender) do
        state_sender = String.downcase(state_sender)
        l2_state_synced_event_signature = Withdrawal.l2_state_synced_event_signature()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == l2_state_synced_event_signature &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_sender
        end)
        |> Enum.map(fn log ->
          Logger.info("Withdrawal message found, id: #{log.second_topic}.")

          Withdrawal.event_to_withdrawal(
            log.second_topic,
            log.data,
            log.transaction_hash,
            log.block_number
          )
        end)
      else
        true ->
          []

        false ->
          Logger.error("L2StateSender contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
