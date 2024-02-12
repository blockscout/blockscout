defmodule Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand do
  @moduledoc """
    On demand fetcher sources for unverified smart contract from [Ethereum Bytecode DB](https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db/eth-bytecode-db)
  """

  use GenServer

  alias Explorer.Chain.{Address, Data, SmartContract}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.SmartContract.EthBytecodeDBInterface
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher

  import Explorer.SmartContract.Helper, only: [prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  @cache_name :smart_contracts_sources_fetching

  @cooldown_timeout 500

  def trigger_fetch(nil, _) do
    :ignore
  end

  def trigger_fetch(address, %SmartContract{partially_verified: true}) do
    GenServer.cast(__MODULE__, {:fetch, address})
  end

  def trigger_fetch(_address, %SmartContract{}) do
    :ignore
  end

  def trigger_fetch(address, _) do
    GenServer.cast(__MODULE__, {:fetch, address})
  end

  defp fetch_sources(address, only_full?) do
    Publisher.broadcast(%{eth_bytecode_db_lookup_started: [address.hash]}, :on_demand)

    creation_tx_input = contract_creation_input(address.hash)

    with {:ok, %{"sourceType" => type, "matchType" => match_type} = source} <-
           %{}
           |> prepare_bytecode_for_microservice(creation_tx_input, Data.to_string(address.contract_code))
           |> EthBytecodeDBInterface.search_contract(address.hash),
         :ok <- check_match_type(match_type, only_full?),
         {:ok, _} <- process_contract_source(type, source, address.hash) do
      Publisher.broadcast(%{smart_contract_was_verified: [address.hash]}, :on_demand)
    else
      _ ->
        Publisher.broadcast(%{smart_contract_was_not_verified: [address.hash]}, :on_demand)
        false
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@cache_name, [
      :set,
      :named_table,
      :public
    ])

    {:ok,
     %{
       current_concurrency: 0,
       max_concurrency:
         Application.get_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)[:max_concurrency]
     }}
  end

  @impl true
  def handle_cast({:fetch, address}, %{current_concurrency: counter, max_concurrency: max_concurrency} = state)
      when counter < max_concurrency do
    handle_fetch_request(address, state)
  end

  @impl true
  def handle_cast({:fetch, _address} = request, %{current_concurrency: _counter} = state) do
    Process.send_after(self(), request, @cooldown_timeout)

    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch, address}, %{current_concurrency: counter, max_concurrency: max_concurrency} = state)
      when counter < max_concurrency do
    handle_fetch_request(address, state)
  end

  @impl true
  def handle_info({:fetch, _address} = request, state) do
    Process.send_after(self(), request, @cooldown_timeout)
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, _answer}, %{current_concurrency: counter} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, %{state | current_concurrency: counter - 1}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{current_concurrency: counter} = state) do
    {:noreply, %{state | current_concurrency: counter - 1}}
  end

  defp partially_verified?(%Address{smart_contract: nil}), do: nil

  defp partially_verified?(%Address{hash: hash}) do
    SmartContract.select_partially_verified_by_address_hash(hash)
  end

  defp check_interval(address_string) do
    fetch_interval =
      Application.get_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)[:fetch_interval]

    case :ets.lookup(@cache_name, address_string) do
      [{_, datetime}] ->
        datetime
        |> DateTime.add(fetch_interval, :millisecond)
        |> DateTime.compare(DateTime.utc_now()) != :gt

      _ ->
        true
    end
  end

  def process_contract_source("SOLIDITY", source, address_hash) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash, true, true, true)
  end

  def process_contract_source("VYPER", source, address_hash) do
    VyperPublisher.process_rust_verifier_response(source, address_hash, true, true, true)
  end

  def process_contract_source("YUL", source, address_hash) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash, true, true, true)
  end

  def process_contract_source(_, _source, _address_hash), do: false

  defp check_match_type("PARTIAL", true), do: :full_match_required
  defp check_match_type(_, _), do: :ok

  defp handle_fetch_request(address, %{current_concurrency: counter} = state) do
    need_to_check_and_partially_verified? =
      check_interval(to_lowercase_string(address.hash)) && partially_verified?(address)

    diff =
      if is_nil(need_to_check_and_partially_verified?) || need_to_check_and_partially_verified? do
        Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
          fetch_sources(address, need_to_check_and_partially_verified?)
        end)

        :ets.insert(@cache_name, {to_lowercase_string(address.hash), DateTime.utc_now()})

        1
      else
        0
      end

    {:noreply, %{state | current_concurrency: counter + diff}}
  end

  defp to_lowercase_string(hash), do: hash |> to_string() |> String.downcase()
end
