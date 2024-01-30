defmodule Indexer.Transform.PolygonEdge.DepositExecutes do
  @moduledoc """
  Helper functions for transforming data for Polygon Edge deposit executes.
  """

  require Logger

  alias Indexer.Fetcher.PolygonEdge.DepositExecute
  alias Indexer.Helper

  @doc """
  Returns a list of deposit executes given a list of logs.
  """
  @spec parse(list()) :: list()
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :polygon_edge_deposit_executes_realtime)

    items =
      with false <-
             is_nil(Application.get_env(:indexer, DepositExecute)[:start_block_l2]),
           state_receiver = Application.get_env(:indexer, DepositExecute)[:state_receiver],
           true <- Helper.address_correct?(state_receiver) do
        state_receiver = String.downcase(state_receiver)
        state_sync_result_event_signature = DepositExecute.state_sync_result_event_signature()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == state_sync_result_event_signature &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_receiver
        end)
        |> Enum.map(fn log ->
          Logger.info("Deposit Execute (StateSyncResult) message found, id: #{log.second_topic}.")

          DepositExecute.event_to_deposit_execute(
            log.second_topic,
            log.third_topic,
            log.transaction_hash,
            log.block_number
          )
        end)
      else
        true ->
          []

        false ->
          Logger.error("StateReceiver contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
