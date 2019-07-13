defmodule Explorer.Staking.ContractState do
  @moduledoc """
  Fetches the following information from StakingAuRa contract:
    - current staking epoch number;
    - the epoch end block number;
    - minimal candidate stake;
    - minimal delegate stake;
    - token contract address.

  Subscribes to new block notifications and refreshes when new staking epoch starts.
  """

  use GenServer

  alias Explorer.Chain.Events.Subscriber
  alias Explorer.SmartContract.Reader

  @table_name __MODULE__

  @doc "Current staking epoch number"
  def epoch_number do
    get(:epoch_number, 0)
  end

  @doc "The end block of current staking epoch"
  def epoch_end_block do
    get(:epoch_end_block, 0)
  end

  @doc "Minimal candidate stake"
  def min_candidate_stake do
    get(:min_candidate_stake, 1)
  end

  @doc "Minimal delegator stake"
  def min_delegator_stake do
    get(:min_delegator_stake, 1)
  end

  @doc "Token contract address"
  def token_contract_address do
    get(:token_contract_address, nil)
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
    {:ok, [], {:continue, []}}
  end

  def handle_continue(_, state) do
    fetch_chain_info()
    {:noreply, state}
  end

  @doc "Handles new blocks and decides to fetch fresh chain info"
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    new_block_number =
      blocks
      |> Enum.map(&Map.get(&1, :number, 0))
      |> Enum.max(fn -> 0 end)

    case :ets.lookup(@table_name, :epoch_end_block) do
      [] ->
        fetch_chain_info()

      [{_, epoch_end_block}] when epoch_end_block < new_block_number ->
        fetch_chain_info()

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp get(param, default) do
    with info when info != :undefined <- :ets.info(@table_name),
         [{_, value}] <- :ets.lookup(@table_name, param) do
      value
    else
      _ -> default
    end
  end

  defp fetch_chain_info do
    with data <- query_contract(),
         {:ok, [epoch_number]} <- data["stakingEpoch"],
         {:ok, [epoch_end_block]} <- data["stakingEpochEndBlock"],
         {:ok, [min_delegator_stake]} <- data["getDelegatorMinStake"],
         {:ok, [min_candidate_stake]} <- data["getCandidateMinStake"],
         {:ok, [token_contract_address]} <- data["erc20TokenContract"] do
      :ets.insert(@table_name, [
        {:epoch_number, epoch_number},
        {:epoch_end_block, epoch_end_block},
        {:min_delegator_stake, min_delegator_stake},
        {:min_candidate_stake, min_candidate_stake},
        {:token_contract_address, token_contract_address}
      ])
    end
  end

  defp query_contract do
    contract_abi = abi("staking.json")

    functions = [
      "stakingEpoch",
      "stakingEpochEndBlock",
      "getDelegatorMinStake",
      "getCandidateMinStake",
      "erc20TokenContract"
    ]

    functions
    |> Enum.map(fn function ->
      %{
        contract_address: staking_contract_address(),
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

  defp staking_contract_address do
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
