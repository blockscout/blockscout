defmodule Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand do
  @moduledoc """
    On demand fetcher sources for unverified smart contract from
    [Ethereum Bytecode DB](https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db/eth-bytecode-db)
  """

  use GenServer

  use Utils.RuntimeEnvHelper,
    fetch_interval: [
      :explorer,
      [
        Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand,
        :fetch_interval
      ]
    ],
    max_concurrency: [
      :explorer,
      [
        Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand,
        :max_concurrency
      ]
    ]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Data, SmartContract}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.SmartContract.EthBytecodeDBInterface
  alias Explorer.SmartContract.Geas.Publisher, as: GeasPublisher
  alias Explorer.SmartContract.Solidity.Publisher, as: SolidityPublisher
  alias Explorer.SmartContract.Vyper.Publisher, as: VyperPublisher
  alias Explorer.Utility.RateLimiter

  import Explorer.SmartContract.Helper, only: [prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  @cache_name :smart_contracts_sources_fetching

  @cooldown_timeout 500

  @doc """
    Triggers the fetch of smart contract sources.

    ## Parameters
      * An `%Address{}` struct with smart contract ALREADY preloaded
      * OR an address hash string

    ## Returns
      * `:ok` - when the fetch request has been scheduled
      * `:ignore` - when the address is not eligible for fetching

    ## Note
    The request is ignored if:
      * The address is not a smart contract
      * The address has empty deployed bytecode (i.e., 0x)
      * The smart contract is already fully verified
  """
  @spec trigger_fetch(String.t() | nil, any()) :: :ignore | :ok
  def trigger_fetch(caller \\ nil, address_or_hash)

  def trigger_fetch(_caller, %Address{
        smart_contract: %SmartContract{
          partially_verified: false
        }
      }) do
    :ignore
  end

  def trigger_fetch(caller, address_or_hash) do
    case RateLimiter.check_rate(caller, :on_demand) do
      :allow -> do_trigger_fetch(address_or_hash)
      :deny -> :ignore
    end
  end

  defp do_trigger_fetch(%Address{} = address) do
    address
    |> Address.smart_contract_with_nonempty_code?()
    |> if do
      GenServer.cast(__MODULE__, {:check_eligibility, address})
    else
      :ignore
    end
  end

  defp do_trigger_fetch(address_hash_string) when is_binary(address_hash_string) do
    GenServer.cast(__MODULE__, {:check_eligibility, address_hash_string})
  end

  defp do_trigger_fetch(_address) do
    :ignore
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
       max_concurrency: max_concurrency()
     }}
  end

  @impl true
  def handle_cast({:check_eligibility, address_or_hash_string}, state) do
    check_eligibility_for_sources_fetching(address_or_hash_string, state)
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
  def handle_info({:check_eligibility, address_or_hash_string}, state) do
    check_eligibility_for_sources_fetching(address_or_hash_string, state)
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

  def process_contract_source("SOLIDITY", source, address_hash_string) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source("VYPER", source, address_hash_string) do
    VyperPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source("YUL", source, address_hash_string) do
    SolidityPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
  end

  def process_contract_source("GEAS", source, address_hash_string) do
    GeasPublisher.process_rust_verifier_response(source, address_hash_string, %{}, true, true, true)
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

    :ets.insert(@cache_name, {String.downcase(address_hash_string), DateTime.utc_now()})

    diff = 1

    {:noreply, %{state | current_concurrency: counter + diff}}
  end

  defp fetch_cooldown_elapsed?(%Address{hash: hash}) do
    hash
    |> to_string()
    |> fetch_cooldown_elapsed?()
  end

  defp fetch_cooldown_elapsed?(address_hash_string) when is_binary(address_hash_string) do
    address_hash_string_downcase = address_hash_string |> String.downcase()

    case :ets.lookup(@cache_name, address_hash_string_downcase) do
      [{_, datetime}] ->
        datetime
        |> DateTime.add(fetch_interval(), :millisecond)
        |> DateTime.compare(DateTime.utc_now()) != :gt

      _ ->
        true
    end
  end

  defp maybe_fetch_address(address_hash_string) when is_binary(address_hash_string) do
    address_hash_string
    |> Chain.hash_to_address(
      necessity_by_association: %{
        :smart_contract => :optional
      }
    )
  end

  # Note: This function expects that the address will come with preloaded smart
  # contract association.
  defp maybe_fetch_address(%Address{} = address) do
    {:ok, address}
  end

  defp check_eligibility_for_sources_fetching(address_or_address_hash_string, state) do
    with true <- fetch_cooldown_elapsed?(address_or_address_hash_string),
         {:ok, address} <- maybe_fetch_address(address_or_address_hash_string),
         true <- Address.smart_contract_with_nonempty_code?(address),
         partially_verified? = address.smart_contract && address.smart_contract.partially_verified,
         true <- is_nil(partially_verified?) or partially_verified? do
      GenServer.cast(
        __MODULE__,
        {
          :fetch,
          to_string(address.hash),
          address.contract_code,
          partially_verified?
        }
      )

      {:noreply, state}
    else
      _ -> {:noreply, state}
    end
  end
end
