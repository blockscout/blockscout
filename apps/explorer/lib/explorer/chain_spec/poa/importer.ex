defmodule Explorer.ChainSpec.POA.Importer do
  @moduledoc """
  Imports emission reward range for POA chain.
  """

  require Logger

  alias Explorer.Chain.Wei
  alias Explorer.Repo
  alias Explorer.SmartContract.Reader
  alias Explorer.Chain.Block.{EmissionReward, Range}
  alias Explorer.ChainSpec.GenesisData

  @block_reward_amount_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "blockRewardAmount",
    "inputs" => [],
    "constant" => true
  }
  @block_reward_amount_params %{"blockRewardAmount" => []}
  @emission_funds_amount_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "emissionFundsAmount",
    "inputs" => [],
    "constant" => true
  }
  @emission_funds_amount_params %{"emissionFundsAmount" => []}
  @emission_funds_block_start 5_098_087

  def import_emission_rewards do
    if is_nil(rewards_contract_address()) do
      Logger.warn(fn -> "No rewards contract address is defined" end)
    else
      block_reward = block_reward_amount()
      emission_funds = emission_funds_amount()

      rewards = [
        %{
          block_range: %Range{from: 0, to: @emission_funds_block_start},
          reward: %Wei{value: block_reward}
        },
        %{
          block_range: %Range{from: @emission_funds_block_start + 1, to: :infinity},
          reward: %Wei{value: Decimal.add(block_reward, emission_funds)}
        }
      ]

      {_, nil} = Repo.delete_all(EmissionReward)
      {_, nil} = Repo.insert_all(EmissionReward, rewards)
    end
  end

  def block_reward_amount do
    call_contract(rewards_contract_address(), @block_reward_amount_abi, @block_reward_amount_params)
  end

  def emission_funds_amount do
    call_contract(rewards_contract_address(), @emission_funds_amount_abi, @emission_funds_amount_params)
  end

  defp rewards_contract_address do
    Application.get_env(:explorer, GenesisData)[:rewards_contract_address]
  end

  defp call_contract(address, abi, params) do
    abi = [abi]

    method_name =
      params
      |> Enum.map(fn {key, _value} -> key end)
      |> List.first()

    Reader.query_contract(address, abi, params)

    value =
      case Reader.query_contract(address, abi, params) do
        %{^method_name => {:ok, [result]}} -> result
        _ -> 0
      end

    Decimal.new(value)
  end
end
