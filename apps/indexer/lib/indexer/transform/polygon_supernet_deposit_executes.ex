defmodule Indexer.Transform.PolygonSupernetDepositExecutes do
  @moduledoc """
  Helper functions for transforming data for Polygon Supernet deposit executes.
  """

  require Logger

  alias Indexer.Fetcher.PolygonSupernetDepositExecute
  alias Indexer.Helper

  @doc """
  Returns a list of deposit executes given a list of logs.
  """
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :polygon_supernet_deposit_executes_realtime)

    items =
      with false <-
             is_nil(Application.get_env(:indexer, PolygonSupernetDepositExecute)[:start_block_l2]),
           state_receiver = Application.get_env(:indexer, PolygonSupernetDepositExecute)[:state_receiver],
           true <- Helper.is_address_correct?(state_receiver) do
        state_receiver = String.downcase(state_receiver)
        state_sync_result_event_signature = PolygonSupernetDepositExecute.state_sync_result_event_signature()

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == state_sync_result_event_signature &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_receiver
        end)
        |> Enum.map(fn log ->
          Logger.info("Deposit Execute (StateSyncResult) message found, id: #{log.second_topic}.")

          PolygonSupernetDepositExecute.event_to_deposit_execute(
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
