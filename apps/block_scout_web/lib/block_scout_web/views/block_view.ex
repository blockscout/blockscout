defmodule BlockScoutWeb.BlockView do
  use BlockScoutWeb, :view

  import Math.Enum, only: [mean: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Wei}
  alias Explorer.Chain.Block.Reward

  @dialyzer :no_match

  def average_gas_price(%Block{transactions: transactions}) do
    average =
      transactions
      |> Enum.map(&Decimal.to_float(Wei.to(&1.gas_price, :gwei)))
      |> mean()
      |> Kernel.||(0)
      |> BlockScoutWeb.Cldr.Number.to_string!()

    unit_text = gettext("Gwei")

    "#{average} #{unit_text}"
  end

  def block_type(%Block{consensus: false, nephews: []}), do: "Reorg"
  def block_type(%Block{consensus: false}), do: "Uncle"
  def block_type(_block), do: "Block"

  def block_miner(block) do
    if block.miner.names == [] and
         Ecto.assoc_loaded?(block.celo_delegator) and
         block.celo_delegator != nil and
         block.celo_delegator.celo_account != nil and
         Ecto.assoc_loaded?(block.celo_delegator.celo_account) and
         block.celo_delegator.celo_account.name != nil do
      named = %Address.Name{
        address: block.celo_delegator.celo_account.account_address,
        address_hash: block.celo_delegator.celo_account.address,
        name: block.celo_delegator.celo_account.name <> " (signer)",
        primary: true,
        metadata: %{}
      }

      %{block.miner | names: [named]}
    else
      block.miner
    end
  end

  @doc """
  Work-around for spec issue in `Cldr.Unit.to_string!/1`
  """
  def cldr_unit_to_string!(unit) do
    # We do this to trick Dialyzer to not complain about non-local returns caused by bug in Cldr.Unit.to_string! spec
    case :erlang.phash2(1, 1) do
      0 ->
        BlockScoutWeb.Cldr.Unit.to_string!(unit)

      1 ->
        # does not occur
        ""
    end
  end

  def round_to_string!(nil) do
    "0"
  end

  def round_to_string!(num) do
    BlockScoutWeb.Cldr.Number.to_string!(num)
  end

  def formatted_gas(gas, format \\ []) do
    BlockScoutWeb.Cldr.Number.to_string!(gas, format)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end

  def show_reward?([]), do: false
  def show_reward?(_), do: true

  def block_reward_text(%Reward{address_type: :validator}) do
    gettext("Miner Reward")
  end

  def block_reward_text(%Reward{address_type: :emission_funds}) do
    gettext("Emission Reward")
  end

  def block_reward_text(%Reward{address_type: :uncle}) do
    gettext("Uncle Reward")
  end

  def combined_rewards_value(block) do
    block
    |> Chain.block_combined_rewards()
    |> format_wei_value(:ether)
  end
end
