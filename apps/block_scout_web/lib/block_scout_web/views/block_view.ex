defmodule BlockScoutWeb.BlockView do
  use BlockScoutWeb, :view

  import Math.Enum, only: [mean: 1]

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Wei}
  alias Explorer.Chain.Block.Reward
  alias Explorer.SmartContract.Reader

  @dialyzer :no_match

  @get_payout_by_mining_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address", "name" => ""}],
    "name" => "getPayoutByMining",
    "inputs" => [%{"type" => "address", "name" => ""}],
    "constant" => true
  }

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

  def formatted_gas(gas, format \\ []) do
    BlockScoutWeb.Cldr.Number.to_string!(gas, format)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end

  def show_reward?([]), do: false
  def show_reward?(_), do: true

  def block_reward_text(%Reward{address_hash: beneficiary_address, address_type: :validator}, block_miner_address) do
    if Application.get_env(:explorer, Explorer.Chain.Block.Reward, %{})[:keys_manager_contract_address] do
      %{payout_key: block_miner_payout_address} = Reward.get_validator_payout_key_by_mining(block_miner_address)

      if beneficiary_address == block_miner_payout_address do
        gettext("Miner Reward")
      else
        gettext("Chore Reward")
      end
    else
      gettext("Miner Reward")
    end
  end

  def block_reward_text(%Reward{address_type: :emission_funds}, _block_miner_address) do
    gettext("Emission Reward")
  end

  def block_reward_text(%Reward{address_type: :uncle}, _block_miner_address) do
    gettext("Uncle Reward")
  end

  def combined_rewards_value(block) do
    block
    |> Chain.block_combined_rewards()
    |> format_wei_value(:ether)
  end

  defp call_contract(address, abi, params) do
    abi = [abi]

    method_name =
      params
      |> Enum.map(fn {key, _value} -> key end)
      |> List.first()

    value =
      case Reader.query_contract(address, abi, params) do
        %{^method_name => {:ok, [result]}} -> result
        _ -> "0x0000000000000000000000000000000000000000"
      end

    type =
      abi
      |> Enum.at(0)
      |> Map.get("outputs", [])
      |> Enum.at(0)
      |> Map.get("type", "")

    case type do
      "address" ->
        "0x" <> Base.encode16(value, case: :lower)

      _ ->
        value
    end
  end
end
