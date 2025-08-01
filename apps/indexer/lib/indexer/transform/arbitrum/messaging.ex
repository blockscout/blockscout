defmodule Indexer.Transform.Arbitrum.Messaging do
  @moduledoc """
    Helper functions for transforming data for Arbitrum cross-chain messages.
  """

  alias Explorer.Chain.Arbitrum.Message
  alias Indexer.Fetcher.Arbitrum.Messaging, as: ArbitrumMessages

  require Logger

  @doc """
    Parses and combines lists of rollup transactions and logs to identify and process both L1-to-L2 and L2-to-L1 messages.

    This function utilizes two filtering operations: one that identifies L1-to-L2
    message completions from a list of transactions, as well as the transactions
    suspected of containing messages but requiring additional handling due to
    hashed message IDs; and another that identifies L2-to-L1 message initiations
    from a list of logs.

    ## Parameters
    - `transactions`: A list of rollup transaction entries to filter for L1-to-L2 messages.
    - `logs`: A list of log entries to filter for L2-to-L1 messages.

    ## Returns
    A tuple containing:
    - A combined list of detailed message maps from both L1-to-L2 completions and
      L2-to-L1 initiations, ready for database import.
    - A list of transactions with hashed message IDs that require further processing.
  """
  @spec parse([map()], [map()]) :: {[Message.to_import()], [map()]}
  def parse(transactions, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :arbitrum_bridge_l2)

    {l1_to_l2_completion_ops, transactions_with_hashed_message_id} =
      transactions
      |> ArbitrumMessages.filter_l1_to_l2_messages()

    l2_to_l1_initiating_ops =
      logs
      |> ArbitrumMessages.filter_l2_to_l1_messages()

    Logger.reset_metadata(prev_metadata)

    {l1_to_l2_completion_ops ++ l2_to_l1_initiating_ops, transactions_with_hashed_message_id}
  end
end
