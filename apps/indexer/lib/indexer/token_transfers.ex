defmodule Indexer.TokenTransfers do
  @moduledoc """
  Context for working with token transfers.
  """

  alias Indexer.TokenTransfer.Parser

  defdelegate parse(items), to: Parser
end
