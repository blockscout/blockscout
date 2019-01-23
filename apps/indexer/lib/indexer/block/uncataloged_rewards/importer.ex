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
        |> add_gas_payments()
        |> Enum.map(&Reward.changeset(%Reward{}, &1))
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

  defp add_gas_payments(beneficiaries) do
    Enum.map(beneficiaries, fn beneficiary ->
      case beneficiary.address_type do
        :validator ->
          gas_payment = gas_payment(beneficiary)

          {:ok, minted} = Wei.cast(beneficiary.reward)

          %{beneficiary | reward: Wei.sum(minted, gas_payment)}

        _ ->
          beneficiary
      end
    end)
  end

  defp gas_payment(beneficiary) do
    {:ok, initial} = Wei.cast(0)

    beneficiary.block_number
    |> Chain.get_transactions_of_block_number()
    |> Enum.reduce(initial, fn %Transaction{gas_price: gas_price, gas_used: gas_used}, acc ->
      gas_price
      |> Wei.mult(gas_used)
      |> Wei.sum(acc)
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
