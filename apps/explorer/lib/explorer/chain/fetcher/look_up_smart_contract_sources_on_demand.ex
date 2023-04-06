defmodule Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand do
  @moduledoc """
    On demand fetcher sources for unverified smart contract from [Ethereum Bytecode DB](https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db/eth-bytecode-db)
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Data, SmartContract}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.SmartContract.RustVerifierInterface
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher

  import Explorer.SmartContract.Helper, only: [prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  @cache_name :smart_contracts_sources_fetching

  # seconds
  @fetch_interval 600

  def trigger_fetch(nil, _) do
    :ignore
  end

  def trigger_fetch(_address, %SmartContract{}) do
    :ignore
  end

  def trigger_fetch(address, _) do
    GenServer.cast(__MODULE__, {:fetch, address})
  end

  defp fetch_sources(address) do
    creation_tx_input = contract_creation_input(address.hash)

    with {:ok, %{"sourceType" => type} = source} <-
           %{}
           |> prepare_bytecode_for_microservice(creation_tx_input, Data.to_string(address.contract_code))
           |> RustVerifierInterface.search_contract(),
         {:ok, _} <- process_contract_source(type, source, address.hash) do
      Publisher.broadcast(%{smart_contract_was_verified: [address.hash]}, :on_demand)
    else
      _ ->
        false
    end

    :ets.insert(@cache_name, {to_string(address.hash), DateTime.utc_now()})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    :ets.new(@cache_name, [
      :set,
      :named_table,
      :public
    ])

    {:ok, opts}
  end

  @impl true
  def handle_cast({:fetch, address}, state) do
    if need_to_fetch_sources?(address) && check_interval(to_string(address.hash)) do
      fetch_sources(address)
    end

    {:noreply, state}
  end

  defp need_to_fetch_sources?(%Address{smart_contract: nil}), do: true

  defp need_to_fetch_sources?(%Address{hash: hash}) do
    case Chain.address_hash_to_one_smart_contract(hash) do
      nil ->
        true

      _ ->
        false
    end
  end

  defp check_interval(address_string) do
    case :ets.lookup(@cache_name, address_string) do
      [{_, datetime}] ->
        datetime
        |> DateTime.add(@fetch_interval, :second)
        |> DateTime.compare(DateTime.utc_now()) != :gt

      _ ->
        true
    end
  end

  def process_contract_source("SOLIDITY", source, address_hash) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash, true, true)
  end

  def process_contract_source("VYPER", source, address_hash) do
    VyperPublisher.process_rust_verifier_response(source, address_hash, true)
  end

  def process_contract_source("YUL", source, address_hash) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash, true, true)
  end

  def process_contract_source(_, _source, _address_hash), do: false
end
