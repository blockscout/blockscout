defmodule BlockScoutWeb.BlockSignersView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Address

  import BlockScoutWeb.Gettext, only: [gettext: 1]

  def get_member(member) do
    if member.names == [] and
         Ecto.assoc_loaded?(member.celo_delegator) and
         member.celo_delegator != nil and
         member.celo_delegator.celo_account != nil do
      named = %Address.Name{
        address: member.celo_delegator.celo_account.account_address,
        address_hash: member.celo_delegator.celo_account.address,
        name: member.celo_delegator.celo_account.name <> " (signer)",
        primary: true,
        metadata: %{}
      }

      %{member | names: [named]}
    else
      member
    end
  end

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
