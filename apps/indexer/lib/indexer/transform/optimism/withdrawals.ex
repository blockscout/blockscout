defmodule Indexer.Transform.Optimism.Withdrawals do
  @moduledoc """
  Helper functions for transforming data for Optimism withdrawals.
  """

  require Logger

  alias Indexer.Fetcher.Optimism.Withdrawal, as: OptimismWithdrawal
  alias Indexer.Helper

  # 32-byte signature of the event MessagePassed(uint256 indexed nonce, address indexed sender, address indexed target, uint256 value, uint256 gasLimit, bytes data, bytes32 withdrawalHash)
  @message_passed_event "0x02a52367d10742d8032712c1bb8e0144ff1ec5ffda1ed7d70bb05a2744955054"

  @doc """
  Returns a list of withdrawals given a list of logs.
  """
  def parse(logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :optimism_withdrawals_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, OptimismWithdrawal)[:start_block_l2]),
           message_passer = Application.get_env(:indexer, OptimismWithdrawal)[:message_passer],
           true <- Helper.address_correct?(message_passer) do
        message_passer = String.downcase(message_passer)

        logs
        |> Enum.filter(fn log ->
          !is_nil(log.first_topic) && String.downcase(log.first_topic) == @message_passed_event &&
            String.downcase(Helper.address_hash_to_string(log.address_hash)) == message_passer
        end)
        |> Enum.map(fn log ->
          Logger.info("Withdrawal message found, nonce: #{log.second_topic}.")
          OptimismWithdrawal.event_to_withdrawal(log.second_topic, log.data, log.transaction_hash, log.block_number)
        end)
      else
        true ->
          []

        false ->
          Logger.error("L2ToL1MessagePasser contract address is incorrect. Cannot use #{__MODULE__} for parsing logs.")
          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
