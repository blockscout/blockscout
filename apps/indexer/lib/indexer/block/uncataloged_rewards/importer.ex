defmodule Indexer.Block.UncatalogedRewards.Importer do
  @moduledoc """
  a module to fetch and import the rewards for blocks that were indexed without the reward
  """

  alias Ecto.Multi
  alias EthereumJSONRPC.FetchedBeneficiaries
  alias Explorer.Chain
  alias Explorer.Chain.{Block.Reward, Wei}

  # max number of blocks in a single request
  # higher numbers may cause the requests to time out
  # lower numbers will generate more requests
  @chunk_size 10

  @doc """
  receives a list of blocks and tries to fetch and insert rewards for them
  """
  def fetch_and_import_rewards(blocks) when is_list(blocks) do
    result =
      blocks
      |> Stream.map(& &1.number)
      |> Stream.chunk_every(@chunk_size)
      |> Enum.reduce([], fn chunk, acc ->
        chunk
        |> fetch_beneficiaries()
        |> fetch_block_rewards()
        |> insert_reward_group()
        |> case do
          :empty -> acc
          insert -> [insert | acc]
        end
      end)

    {:ok, result}
  rescue
    e in RuntimeError -> {:error, %{exception: e}}
  end

  defp fetch_beneficiaries(block_numbers) when is_list(block_numbers) do
    {:ok, %FetchedBeneficiaries{params_set: result}} =
      with :ignore <- EthereumJSONRPC.fetch_beneficiaries(block_numbers, json_rpc_named_arguments()) do
        {:ok, %FetchedBeneficiaries{params_set: MapSet.new()}}
      end

    result
  end

  defp fetch_block_rewards(beneficiaries) do
    Enum.map(beneficiaries, fn beneficiary ->
      beneficiary_changes =
        case beneficiary.address_type do
          :validator ->
            validation_reward = fetch_validation_reward(beneficiary)

            {:ok, reward} = Wei.cast(beneficiary.reward)

            %{beneficiary | reward: Wei.sum(reward, validation_reward)}

          _ ->
            beneficiary
        end

      Reward.changeset(%Reward{}, beneficiary_changes)
    end)
  end

  defp fetch_validation_reward(beneficiary) do
    {:ok, accumulator} = Wei.cast(0)

    beneficiary.block_number
    |> Chain.get_transactions_of_block_number()
    |> Enum.reduce(accumulator, fn t, acc ->
      {:ok, price_as_wei} = Wei.cast(t.gas_used)
      price_as_wei |> Wei.mult(t.gas_price) |> Wei.sum(acc)
    end)
  end

  defp insert_reward_group([]), do: :empty

  defp insert_reward_group(rewards) do
    rewards
    |> Enum.reduce({Multi.new(), 0}, fn changeset, {multi, index} ->
      {Multi.insert(multi, "insert_#{index}", changeset,
         conflict_target: ~w(address_hash address_type block_hash),
         on_conflict: {:replace, [:reward]}
       ), index + 1}
    end)
    |> elem(0)
    |> Explorer.Repo.transaction()
  end

  defp json_rpc_named_arguments do
    Application.get_env(:explorer, :json_rpc_named_arguments)
  end
end
