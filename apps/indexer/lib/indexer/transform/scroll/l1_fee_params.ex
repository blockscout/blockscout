defmodule Indexer.Transform.Scroll.L1FeeParams do
  @moduledoc """
    Helper functions for transforming data for Scroll L1 fee parameters.
  """

  require Logger

  @doc """
  Returns a list of params given a list of logs.
  """
  def parse(_logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :scroll_l1_fee_params_realtime)

    # if Application.get_env(:explorer, :chain_type) == :scroll do
    items = []

    Logger.reset_metadata(prev_metadata)

    items
  end
end
