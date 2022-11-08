defmodule Indexer.Transform.TransactionActions do
  @moduledoc """
  Helper functions for transforming data for transaction actions.
  """

  require Logger

  alias ABI.TypeDecoder
  alias Explorer.Token.MetadataRetriever

  @doc """
  Returns a list of transaction actions given a list of logs.
  """
  def parse(logs) do
    actions = []
    %{transaction_actions: actions}
  end
end
