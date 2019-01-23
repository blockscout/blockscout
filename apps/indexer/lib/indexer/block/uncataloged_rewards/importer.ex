defmodule Indexer.Block.UncatalogedRewards.Importer do
  @moduledoc """
  a module to fetch and import the rewards for blocks that were indexed without the reward
  """

  alias EthereumJSONRPC.FetchedBeneficiaries
  alias Explorer.Chain
  alias Explorer.Chain.Wei

  # max number of blocks in a single request
  # higher numbers may cause the requests to time out
  # lower numbers will generate more requests
  @chunk_size 10

  @doc """
  receives a list of blocks and tries to fetch and insert rewards for them
  """
  def fetch_and_import_rewards(blocks) when is_list(blocks) do
    block_rewards =
      blocks
      |> Stream.map(& &1.number)
      |> Stream.chunk_every(@chunk_size)
      |> Enum.flat_map(&block_numbers_to_rewards/1)

    {:ok, block_rewards}
  rescue
    e in RuntimeError -> {:error, %{exception: e}}
  end

  defp block_numbers_to_rewards(block_numbers) when is_list(block_numbers) do
    case fetch_beneficiaries(block_numbers) do
      [] ->
        []

      beneficiaries_params ->
        beneficiaries_params
        |> add_gas_payments()
        |> import_block_reward_params()
        |> case do
          {:ok, %{block_rewards: block_rewards}} -> block_rewards
        end
    end
  end

  defp fetch_beneficiaries(block_numbers) when is_list(block_numbers) do
    {:ok, %FetchedBeneficiaries{params_set: result}} =
      with :ignore <- EthereumJSONRPC.fetch_beneficiaries(block_numbers, json_rpc_named_arguments()) do
        {:ok, %FetchedBeneficiaries{params_set: MapSet.new()}}
      end

    Enum.sort_by(result, &{&1.address_hash, &1.address_type, &1.block_hash})
  end

  defp add_gas_payments(beneficiaries) do
    gas_payment_by_block_hash =
      beneficiaries
      |> Stream.filter(&(&1.address_type == :validator))
      |> Enum.map(& &1.block_hash)
      |> Chain.gas_payment_by_block_hash()

    Enum.map(beneficiaries, fn %{block_hash: block_hash} = beneficiary ->
      case gas_payment_by_block_hash do
        %{^block_hash => gas_payment} ->
          {:ok, minted} = Wei.cast(beneficiary.reward)
          %{beneficiary | reward: Wei.sum(minted, gas_payment)}

        _ ->
          beneficiary
      end
    end)
  end

  defp import_block_reward_params(block_rewards_params) when is_list(block_rewards_params) do
    Chain.import(%{block_rewards: %{params: block_rewards_params}})
  end

  defp json_rpc_named_arguments do
    Application.get_env(:explorer, :json_rpc_named_arguments)
  end
end
