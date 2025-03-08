defmodule Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand do
  @moduledoc """
    On demand fetcher sources for unverified smart contract from
    [Ethereum Bytecode DB](https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db/eth-bytecode-db)
  """

  use GenServer

  alias Explorer.Chain.{Data, SmartContract}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.SmartContract.EthBytecodeDBInterface
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher

  import Explorer.SmartContract.Helper, only: [prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  @cache_name :smart_contracts_sources_fetching

  @cooldown_timeout 500

  def trigger_fetch(nil, _, _) do
    :ignore
  end

  def trigger_fetch(
        address_hash_string,
        address_contract_code,
        %SmartContract{partially_verified: true}
      ) do
    GenServer.cast(__MODULE__, {:check_eligibility, address_hash_string, address_contract_code, false})
  end

  def trigger_fetch(_address_hash_string, _address_contract_code, %SmartContract{}) do
    :ignore
  end

  def trigger_fetch(address_hash_string, address_contract_code, smart_contract) do
    GenServer.cast(__MODULE__, {:check_eligibility, address_hash_string, address_contract_code, is_nil(smart_contract)})
  end

  defp fetch_sources(address_hash_string, address_contract_code, only_full?) do
    Publisher.broadcast(%{eth_bytecode_db_lookup_started: [address_hash_string]}, :on_demand)

    creation_transaction_input = contract_creation_input(address_hash_string)

    with {:ok, %{"sourceType" => type, "matchType" => match_type} = source} <-
           %{}
           |> prepare_bytecode_for_microservice(creation_transaction_input, Data.to_string(address_contract_code))
           |> EthBytecodeDBInterface.search_contract(address_hash_string),
         :ok <- check_match_type(match_type, only_full?),
         {:ok, _} <- process_contract_source(type, source, address_hash_string) do
      Publisher.broadcast(%{smart_contract_was_verified: [address_hash_string]}, :on_demand)
    else
      _ ->
        Publisher.broadcast(%{smart_contract_was_not_verified: [address_hash_string]}, :on_demand)
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
  def handle_cast({:check_eligibility, address_hash_string, address_contract_code, nil_smart_contract?}, state) do
    check_eligibility_for_sources_fetching(address_hash_string, address_contract_code, nil_smart_contract?, state)
  end

  @impl true
  def handle_cast(
        {:fetch, address_hash_string, address_contract_code, need_to_check_and_partially_verified?},
        %{current_concurrency: counter, max_concurrency: max_concurrency} = state
      )
      when counter < max_concurrency do
    handle_fetch_request(address_hash_string, address_contract_code, need_to_check_and_partially_verified?, state)
  end

  @impl true
  def handle_cast(
        {:fetch, _address_hash_string, _address_contract_code, _need_to_check_and_partially_verified?} = request,
        %{current_concurrency: _counter} = state
      ) do
    Process.send_after(self(), request, @cooldown_timeout)
    {:noreply, state}
  end

  @impl true
  def handle_info({:check_eligibility, address_hash_string, address_contract_code, nil_smart_contract?}, state) do
    check_eligibility_for_sources_fetching(address_hash_string, address_contract_code, nil_smart_contract?, state)
  end

  @impl true
  def handle_info(
        {:fetch, address_hash_string, address_contract_code, need_to_check_and_partially_verified?},
        %{current_concurrency: counter, max_concurrency: max_concurrency} = state
      )
      when counter < max_concurrency do
    handle_fetch_request(address_hash_string, address_contract_code, need_to_check_and_partially_verified?, state)
  end

  @impl true
  def handle_info(
        {:fetch, _address_hash_string, _address_contract_code, _need_to_check_and_partially_verified?} = request,
        state
      ) do
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

  defp partially_verified?(_address_hash_string, true), do: nil

  defp partially_verified?(address_hash_string, _nil_smart_contract?) do
    SmartContract.select_partially_verified_by_address_hash(address_hash_string)
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

  def process_contract_source("SOLIDITY", source, address_hash_string) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source("VYPER", source, address_hash_string) do
    VyperPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source("YUL", source, address_hash_string) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source(_, _source, _address_hash), do: false

  defp check_match_type("PARTIAL", true), do: :full_match_required
  defp check_match_type(_, _), do: :ok

  defp handle_fetch_request(
         address_hash_string,
         address_contract_code,
         need_to_check_and_partially_verified?,
         %{
           current_concurrency: counter
         } = state
       ) do
    Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
      fetch_sources(address_hash_string, address_contract_code, need_to_check_and_partially_verified?)
    end)

    :ets.insert(@cache_name, {to_lowercase_string(address_hash_string), DateTime.utc_now()})

    diff = 1

    {:noreply, %{state | current_concurrency: counter + diff}}
  end

  defp eligible_for_sources_fetching?(need_to_check_and_partially_verified?) do
    is_nil(need_to_check_and_partially_verified?) || need_to_check_and_partially_verified?
  end

  @spec stale_and_partially_verified?(String.t(), boolean()) :: boolean() | nil
  defp stale_and_partially_verified?(address_hash_string, nil_smart_contract?) do
    check_interval(to_lowercase_string(address_hash_string)) &&
      partially_verified?(address_hash_string, nil_smart_contract?)
  end

  defp check_eligibility_for_sources_fetching(address_hash_string, address_contract_code, nil_smart_contract?, state) do
    need_to_check_and_partially_verified? = stale_and_partially_verified?(address_hash_string, nil_smart_contract?)

    eligibility_for_sources_fetching = eligible_for_sources_fetching?(need_to_check_and_partially_verified?)

    if eligibility_for_sources_fetching do
      GenServer.cast(
        __MODULE__,
        {:fetch, address_hash_string, address_contract_code, need_to_check_and_partially_verified?}
      )
    end

    {:noreply, state}
  end

  defp to_lowercase_string(address_hash_string), do: address_hash_string |> String.downcase()
end
