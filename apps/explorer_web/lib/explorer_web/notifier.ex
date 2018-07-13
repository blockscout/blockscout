defmodule ExplorerWeb.Notifier do
  alias ExplorerWeb.Endpoint

  def block_confirmations(max_numbered_block) when is_integer(max_numbered_block) do
    Endpoint.broadcast("transactions:confirmations", "update", %{block_number: max_numbered_block})
  end
end
