defmodule Indexer.Block.UncatalogedRewards.Importer do
  @moduledoc """
  a module to fetch and import the rewards for blocks that were indexed without the reward
  """

  require Logger

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
  def fetch_and_import_rewards(blocks, json_rpc_named_arguments) when is_list(blocks) do
    block_rewards =
      blocks
      |> Stream.chunk_every(@chunk_size)
      |> Enum.flat_map(&blocks_to_rewards(&1, json_rpc_named_arguments))

    {:ok, block_rewards}
  rescue
    e in RuntimeError -> {:error, %{exception: e}}
  end

  defp blocks_to_rewards(blocks, json_rpc_named_arguments) when is_list(blocks) do
    blocks
    |> fetch_beneficiaries(json_rpc_named_arguments)
    |> case do
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

  defp fetch_beneficiaries(blocks, json_rpc_named_arguments) when is_list(blocks) do
    hash_by_number = Enum.into(blocks, %{}, &{&1.number, to_string(&1.hash)})

    hash_by_number
    |> Map.keys()
    |> EthereumJSONRPC.fetch_beneficiaries(json_rpc_named_arguments)
    |> case do
      {:ok, %FetchedBeneficiaries{params_set: params_set}} ->
        params_set_to_consensus_beneficiaries_params(params_set, hash_by_number)

      {:error, reason} ->
        Logger.error(fn -> ["Could not fetch beneficiaries: ", inspect(reason)] end)
        []

      :ignore ->
        []
    end
  end

  defp params_set_to_consensus_beneficiaries_params(params_set, hash_by_number) do
    params_set
    |> Enum.filter(fn %{block_number: block_number, block_hash: block_hash} ->
      case Map.fetch!(hash_by_number, block_number) do
        ^block_hash ->
          true

        other_block_hash ->
          Logger.debug(fn ->
            [
              "fetch beneficiaries reported block number (",
              to_string(block_number),
              ") maps to different (",
              other_block_hash,
              ") block hash than the one in the database (",
              block_hash,
              ").  A reorg has occurred."
            ]
          end)

          false
      end
    end)
    |> Enum.sort_by(&{&1.address_hash, &1.address_type, &1.block_hash})
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
end
