defmodule Indexer.Transform.Arbitrum.Messaging do
  @moduledoc """
  Helper functions for transforming data for Arbitrum L1->L2 messages.
  """

  alias Indexer.Fetcher.Arbitrum.Messaging, as: ArbitrumMessages

  require Logger

  @doc """
  TBD
  """
  @spec parse(list(), list()) :: list()
  def parse(transactions, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :arbitrum_bridge_l2_realtime)

    transactions
    |> Enum.each(fn tx ->
      if tx.type not in [0, 1, 2, 3, 106, 104] do
        Logger.info("Discovered #{tx.hash} with the type #{tx.type}")
      end
    end)

    l1_to_l2_completion_ops =
      transactions
      |> ArbitrumMessages.filter_l1_to_l2_messages()

    l2_to_l1_initiating_ops =
      logs
      |> ArbitrumMessages.filter_l2_to_l1_messages()

    Logger.reset_metadata(prev_metadata)

    l1_to_l2_completion_ops ++ l2_to_l1_initiating_ops
  end
end
