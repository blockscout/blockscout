defmodule Explorer.Staking.EpochCounter do
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

  @doc "Current staking epoch number"
  def epoch_number do
    if :ets.info(@table_name) != :undefined do
      case :ets.lookup(@table_name, @epoch_key) do
        [{_, epoch_num}] ->
          epoch_num

        _ ->
          0
      end
    end
  end

  @doc "Block number on which will start new epoch"
  def epoch_end_block do
    if :ets.info(@table_name) != :undefined do
      case :ets.lookup(@table_name, @epoch_end_key) do
        [{_, epoch_end}] ->
          epoch_end

        _ ->
          0
      end
    end
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
    fetch_epoch_info()
    {:noreply, state}
  end

  @doc "Handles new blocks and decides to fetch new epoch info"
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    new_block_number =
      blocks
      |> Enum.map(&Map.get(&1, :number, 0))
      |> Enum.max(fn -> 0 end)

    case :ets.lookup(@table_name, @epoch_end_key) do
      [] ->
        fetch_epoch_info()

      [{_, epoch_end_block}] when epoch_end_block < new_block_number ->
        fetch_epoch_info()

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp fetch_epoch_info do
    # 794c0c68 = keccak256(stakingEpoch())
    # 8c2243ae = keccak256(stakingEpochEndBlock())
    with data <- get_epoch_info(),
         {:ok, [epoch_num]} <- data["794c0c68"],
         {:ok, [epoch_end_block]} <- data["8c2243ae"] do
      :ets.insert(@table_name, {@epoch_key, epoch_num})
      :ets.insert(@table_name, {@epoch_end_key, epoch_end_block})
    end
  end

  defp get_epoch_info do
    contract_abi = abi("staking.json")

    method_ids = ["794c0c68", "8c2243ae"]

    method_ids
    |> Enum.map(fn method_id ->
      %{
        contract_address: staking_address(),
        method_id: method_id,
        args: []
      }
    end)
    |> Reader.query_contracts(contract_abi)
    |> Enum.zip(method_ids)
    |> Enum.into(%{}, fn {response, method_id} ->
      {method_id, response}
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
