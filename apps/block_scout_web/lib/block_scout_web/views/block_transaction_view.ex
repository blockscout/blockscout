defmodule BlockScoutWeb.BlockTransactionView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.Gettext, only: [gettext: 1]

  def block_not_found_message(block_above_tip) do
    case block_above_tip do
      true ->
        gettext("Easy Cowboy! This block does not exist yet!")

      false ->
        gettext("This block has not been processed yet.")

      _ ->
        gettext("Block not found, please try again later.")
    end
  end
end
