defmodule Explorer.Staking.ChainReader do
  @moduledoc """
  Fetches current staking epoch number and the epoch end block number.
  It subscribes to handle new blocks and conclude whether the epoch is over.
  """

  use GenServer

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.SmartContract.Reader

  @table_name __MODULE__
  @epoch_key "epoch_num"
  @epoch_end_key "epoch_end_block"
  @min_candidate_stake_key "min_candidate_stake"
  @min_delegator_stake_key "min_delegator_stake"

  def get_parameter_or_default(param, default) do
    if :ets.info(@table_name) != :undefined do
      case :ets.lookup(@table_name, param) do
        [{_, value}] -> value
        _ -> default
      end
    end
  end

  @doc "Current staking epoch number"
  def epoch_number do
    get_parameter_or_default(@epoch_key, 0)
  end

  @doc "Current staking epoch number"
  def epoch_end_block do
    get_parameter_or_default(@epoch_end_key, 0)
  end

  @doc "Minimal candidate stake"
  def min_candidate_stake do
    get_parameter_or_default(@min_candidate_stake_key, 1)
  end

  @doc "Minimal delegator stake"
  def min_delegator_stake do
    get_parameter_or_default(@min_delegator_stake_key, 1)
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      write_concurrency: true
    ])

    Subscriber.to(:blocks, :realtime)
    {:ok, [], {:continue, :epoch_info}}
  end

  def handle_continue(:epoch_info, state) do
    fetch_chain_info()
    {:noreply, state}
  end

  @doc "Handles new blocks and decides to fetch fresh chain info"
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    new_block_number =
      blocks
      |> Enum.map(&Map.get(&1, :number, 0))
      |> Enum.max(fn -> 0 end)

    case :ets.lookup(@table_name, @epoch_end_key) do
      [] ->
        fetch_chain_info()

      [{_, epoch_end_block}] when epoch_end_block < new_block_number ->
        fetch_chain_info()

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp fetch_chain_info do
    with data <- get_epoch_info(),
         {:ok, [epoch_num]} <- data["stakingEpoch"],
         {:ok, [epoch_end_block]} <- data["stakingEpochEndBlock"],
         {:ok, [min_delegator_stake]} <- data["getDelegatorMinStake"],
         {:ok, [min_candidate_stake]} <- data["getCandidateMinStake"] do
      :ets.insert(@table_name, {@epoch_key, epoch_num})
      :ets.insert(@table_name, {@epoch_end_key, epoch_end_block})
      :ets.insert(@table_name, {@min_delegator_stake_key, min_delegator_stake})
      :ets.insert(@table_name, {@min_candidate_stake_key, min_candidate_stake})
    end
  end

  defp get_epoch_info do
    contract_abi = abi("staking.json")

    functions = [
      "stakingEpoch",
      "stakingEpochEndBlock",
      "getDelegatorMinStake",
      "getCandidateMinStake"
    ]

    functions
    |> Enum.map(fn function ->
      %{
        contract_address: staking_address(),
        function_name: function,
        args: []
      }
    end)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(functions)
    |> Enum.into(%{}, fn {response, function} ->
      {function, response}
    end)
  end

  defp staking_address do
    Application.get_env(:explorer, __MODULE__, [])[:staking_contract_address]
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/pos/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
