defmodule Indexer.Transform.PolygonSupernetWithdrawals do
  @moduledoc """
  Helper functions for transforming data for Polygon Supernet withdrawals.
  """

  require Logger

  alias Indexer.Fetcher.PolygonSupernetWithdrawal
  alias Indexer.Helper

  # 32-byte signature of the event L2StateSynced(uint256 indexed id, address indexed sender, address indexed receiver, bytes data)
  @l2_state_synced_event "0xedaf3c471ebd67d60c29efe34b639ede7d6a1d92eaeb3f503e784971e67118a5"

  @doc """
  Returns a list of withdrawals given a list of logs.
  """
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :polygon_supernet_withdrawals_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, Indexer.Fetcher.PolygonSupernetWithdrawal)[:start_block_l2]),
           state_sender = Application.get_env(:indexer, Indexer.Fetcher.PolygonSupernetWithdrawal)[:state_sender],
           true <- Helper.is_address_correct?(state_sender) do
        state_sender = String.downcase(state_sender)

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == @l2_state_synced_event &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == state_sender
        end)
        |> Enum.map(fn log ->
          Logger.info("Withdrawal message found, id: #{log.second_topic}.")

          PolygonSupernetWithdrawal.event_to_withdrawal(
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
