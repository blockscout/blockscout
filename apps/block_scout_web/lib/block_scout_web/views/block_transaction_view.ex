defmodule BlockScoutWeb.BlockTransactionView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.Gettext, only: [gettext: 1]

  def block_not_found_message({:ok, true}) do
    gettext("Easy Cowboy! This block does not exist yet!")
  end

  def block_not_found_message({:ok, false}) do
    gettext("This block has not been processed yet.")
  end

  def block_not_found_message({:error, :hash}) do
    gettext("Block not found, please try again later.")
  end
end
