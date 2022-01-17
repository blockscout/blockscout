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

  import Ecto.Query

  @block_reward_amount_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "blockRewardAmount",
    "inputs" => [],
    "constant" => true
  }
  # 26cc2256=keccak256(blockRewardAmount())
  @block_reward_amount_params %{"26cc2256" => []}
  @emission_funds_amount_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "emissionFundsAmount",
    "inputs" => [],
    "constant" => true
  }
  # ee8d75ff=keccak256(emissionFundsAmount())
  @emission_funds_amount_params %{"ee8d75ff" => []}
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

      inner_delete_query =
        from(
          emission_reward in EmissionReward,
          # Enforce EmissionReward ShareLocks order (see docs: sharelocks.md)
          order_by: emission_reward.block_range,
          lock: "FOR UPDATE"
        )

      delete_query =
        from(
          e in EmissionReward,
          join: s in subquery(inner_delete_query),
          on: e.block_range == s.block_range
        )

      # Enforce EmissionReward ShareLocks order (see docs: sharelocks.md)
      ordered_rewards = Enum.sort_by(rewards, & &1.block_range)

      {_, nil} = Repo.delete_all(delete_query)
      {_, nil} = Repo.insert_all(EmissionReward, ordered_rewards)
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

    method_id =
      params
      |> Enum.map(fn {key, _value} -> key end)
      |> List.first()

    Reader.query_contract(address, abi, params, false)

    value =
      case Reader.query_contract(address, abi, params, false) do
        %{^method_id => {:ok, [result]}} -> result
        _ -> 0
      end

    Decimal.new(value)
  end
end
