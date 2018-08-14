defmodule BlockScoutWeb.BlockTransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.BlockView

  defdelegate formatted_timestamp(block), to: BlockView
end
