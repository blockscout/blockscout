defmodule Explorer.Celo.CoreContracts do
  @moduledoc """
    Caches the addresses of core contracts on Celo blockchains
  """

  use GenServer
  alias Explorer.Celo.{AbiHandler, AddressCache}
  alias Explorer.Repo
  alias Explorer.SmartContract.Reader
  alias __MODULE__
  require Logger
  import Ecto.Query

  @behaviour AddressCache

  # address of the registry contract, same across networks
  @registry_address "0x000000000000000000000000000000000000ce10"
  def registry_address, do: @registry_address

  @nil_address "0x0000000000000000000000000000000000000000"

  # full list of core contracts, see https://github.com/celo-org/celo-monorepo/blob/master/packages/protocol/lib/registry-utils.ts
  @core_contracts ~w(Accounts Attestations BlockchainParameters DoubleSigningSlasher DowntimeSlasher Election EpochRewards Escrow Exchange ExchangeEUR ExchangeBRL FeeCurrencyWhitelist Freezer GasPriceMinimum GoldToken Governance GovernanceSlasher GovernanceApproverMultiSig GrandaMento LockedGold Random Reserve ReserveSpenderMultiSig SortedOracles StableToken StableTokenEUR StableTokenBRL TransferWhitelist Validators)
  def contract_list, do: @core_contracts

  ## GenServer Callbacks

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(params \\ %{}) do
    GenServer.start_link(__MODULE__, params, name: __MODULE__)
  end

  @impl true
  def init(params) do
    initial_env_cache =
      case System.fetch_env("SUBNETWORK") do
        {:ok, "Celo"} ->
          cache(:mainnet)

        {:ok, "Alfajores"} ->
          cache(:alfajores)

        {:ok, "Baklava"} ->
          cache(:baklava)

        :error ->
          Logger.warn("No SUBNETWORK env var set for Celo contract address cache, building incrementally")
          %{}
      end

    cache = initial_env_cache |> Map.merge(params[:cache] || %{})

    period = params[:refresh_period] || Application.get_env(:explorer, Explorer.Celo.CoreContracts)[:refresh]
    timer = Process.send_after(self(), :refresh, period)

    state =
      %{cache: cache, timer: timer}
      |> rebuild_state()

    {:ok, state, {:continue, :fetch_contracts_from_db}}
  end

  @impl true
  def handle_continue(:fetch_contracts_from_db, %{cache: cache} = state) do
    db_cache =
      Explorer.Chain.CeloCoreContract
      |> order_by(:block_number)
      |> Repo.all()
      |> Enum.reduce(%{}, fn %{name: name, address_hash: address_hash}, map ->
        Map.put(map, name, to_string(address_hash))
      end)

    new_state =
      state
      |> Map.put(:cache, Map.merge(cache, db_cache))
      |> rebuild_state()

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_address, contract_name}, _from, %{cache: cache} = state) do
    {address, state} =
      case Map.get(cache, contract_name) do
        # not found in cache, fetch directly
        address when address in [nil, @nil_address] ->
          Logger.info("Contract cache miss - #{contract_name}, fetching directly")

          address =
            case get_address_raw(contract_name) do
              {:error, e} ->
                Logger.error("Failed to fetch Celo Contract address for #{contract_name} - #{inspect(e)}")
                nil

              address ->
                address
            end

          state =
            if is_nil(address) do
              state
            else
              state
              |> put_in([:cache, contract_name], address)
              |> rebuild_state()
            end

          {address, state}

        address ->
          {address, state}
      end

    {:reply, address, state}
  end

  @impl true
  def handle_call({:has_address, address}, _from, %{address_set: set} = state) do
    {:reply, MapSet.member?(set, address), state}
  end

  @impl true
  def handle_info(:refresh, %{timer: timer, cache: cache}) do
    # cancel the timer as this method may have been invoked manually
    _ = Process.cancel_timer(timer, info: false)

    refresh_period = Application.get_env(:explorer, Explorer.Celo.CoreContracts)[:refresh]
    refresh_concurrency = Application.get_env(:explorer, Explorer.Celo.CoreContracts)[:refresh_concurrency]

    contracts_to_update = cache |> Map.keys()
    Logger.info("Updating core contract addresses for #{Enum.join(contracts_to_update, ",")}")

    # spawning async tasks for each contract to prevent this process (CoreContracts) being blocked
    # whilst awaiting return from blockchain call
    Explorer.TaskSupervisor
    |> Task.Supervisor.async_stream(
      contracts_to_update,
      fn name ->
        case get_address_raw(name) do
          {:error, e} ->
            Logger.error("Failed to fetch Celo Contract address for #{name} - #{inspect(e)}")

          address when is_binary(address) ->
            CoreContracts.update_cache(name, address)
        end
      end,
      on_timeout: :kill_task,
      max_concurrency: refresh_concurrency,
      ordered: false
    )
    |> Stream.run()

    # schedule next refresh
    timer = Process.send_after(self(), :refresh, refresh_period)
    state_with_new_timer = %{cache: cache, timer: timer} |> rebuild_state()

    {:noreply, state_with_new_timer}
  end

  def handle_info({:update, name, address}, state) do
    new_state =
      state
      |> put_in([:cache, name], address)
      |> rebuild_state()

    {:noreply, new_state}
  end

  ## API Methods

  @doc """
  Return the address associated with the core contract that has a given name
  """
  @impl AddressCache
  def contract_address("Registry"), do: @registry_address

  @impl AddressCache
  def contract_address(name), do: GenServer.call(__MODULE__, {:get_address, name})

  @impl AddressCache
  def update_cache(name, address) do
    send(__MODULE__, {:update, name, address})
  end

  @doc """
  Trigger a refresh of all Celo Core Contract addresses
  """
  def refresh, do: send(__MODULE__, :refresh)

  @impl AddressCache
  def is_core_contract_address?(%Explorer.Chain.Hash{} = address) do
    address
    |> to_string()
    |> is_core_contract_address?()
  end

  @impl AddressCache
  def is_core_contract_address?(address) do
    GenServer.call(__MODULE__, {:has_address, address})
  end

  defp rebuild_state(%{cache: cache, timer: timer}) do
    address_set = cache |> Map.values() |> MapSet.new()

    %{cache: cache, address_set: address_set, timer: timer}
  end

  # Directly query celo blockchain registry contract for core contract addresses
  defp get_address_raw(name) do
    contract_abi = AbiHandler.get_abi()

    methods = [
      %{
        contract_address: @registry_address,
        function_name: "getAddressForString",
        args: [name]
      }
    ]

    res =
      methods
      |> Reader.query_contracts_by_name(contract_abi)
      |> Enum.zip(methods)
      |> Enum.into(%{}, fn {response, %{function_name: function_name}} ->
        {function_name, response}
      end)

    case res["getAddressForString"] do
      {:ok, [address]} -> address
      e -> {:error, e}
    end
  end

  # methods provide initial values only, during runtime addresses will be fetched periodically from the Registry contract
  defp cache(:mainnet) do
    %{
      "Accounts" => "0x7d21685c17607338b313a7174bab6620bad0aab7",
      "Attestations" => "0xdc553892cdeeed9f575aa0fba099e5847fd88d20",
      "BlockchainParameters" => "0x6e10a8864c65434a721d82e424d727326f9d5bfa",
      "DoubleSigningSlasher" => "0x50c100bacde7e2b546371eb0be1eaccf0a6772ec",
      "DowntimeSlasher" => "0x71cac3b31c138f3327c6ca14f9a1c8d752463fdd",
      "Election" => "0x8d6677192144292870907e3fa8a5527fe55a7ff6",
      "EpochRewards" => "0x07f007d389883622ef8d4d347b3f78007f28d8b7",
      "Escrow" => "0xf4fa51472ca8d72af678975d9f8795a504e7ada5",
      "Exchange" => "0x67316300f17f063085ca8bca4bd3f7a5a3c66275",
      "ExchangeEUR" => "0xe383394b913d7302c49f794c7d3243c429d53d1d",
      "ExchangeBRL" => "0x8f2cf9855C919AFAC8Bd2E7acEc0205ed568a4EA",
      "FeeCurrencyWhitelist" => "0xbb024e9cdcb2f9e34d893630d19611b8a5381b3c",
      "Freezer" => "0x47a472f45057a9d79d62c6427367016409f4ff5a",
      "GasPriceMinimum" => "0xdfca3a8d7699d8bafe656823ad60c17cb8270ecc",
      "GoldToken" => "0x471ece3750da237f93b8e339c536989b8978a438",
      "Governance" => "0xd533ca259b330c7a88f74e000a3faea2d63b7972",
      "GovernanceApproverMultiSig" => "0x0000000000000000000000000000000000000000",
      "GovernanceSlasher" => "0xf2a347f184b0fef572c7cbd2c392359eccf43f3c",
      "GrandaMento" => "0x03f6842b82dd2c9276931a17dd23d73c16454a49",
      "LockedGold" => "0x6cc083aed9e3ebe302a6336dbc7c921c9f03349e",
      "Random" => "0x22a4aaf42a50bfa7238182460e32f15859c93dfe",
      "Reserve" => "0x9380fa34fd9e4fd14c06305fd7b6199089ed4eb9",
      "ReserveSpenderMultiSig" => "0x0000000000000000000000000000000000000000",
      "SortedOracles" => "0xefb84935239dacdecf7c5ba76d8de40b077b7b33",
      "StableToken" => "0x765de816845861e75a25fca122bb6898b8b1282a",
      "StableTokenEUR" => "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73",
      "StableTokenBRL" => "0xe8537a3d056da446677b9e9d6c5db704eaab4787",
      "TransferWhitelist" => "0xb49e4d6f0b7f8d0440f75697e6c8b37e09178bcf",
      "Validators" => "0xaeb865bca93ddc8f47b8e29f40c5399ce34d0c58"
    }
  end

  defp cache(:baklava) do
    %{
      "Accounts" => "0x64ff4e6f7e08119d877fd2e26f4c20b537819080",
      "Attestations" => "0xaeb505a8ba97241cc85d98c2e892608dd16da3cc",
      "BlockchainParameters" => "0x2f6feacb6a4326c47e5ac16dddb5542adaf45fc8",
      "DoubleSigningSlasher" => "0x9c2fbf60aa2a8ddc73c499c9b724e86d8c15f72f",
      "DowntimeSlasher" => "0xc743c9a58050a669ec4aff41d8a6c76f2264e206",
      "Election" => "0x7eb2b2f696c60a48afd7632f280c7de91c8e5aa5",
      "EpochRewards" => "0xfdc7d3da53ca155ddce793b0de46f4c29230eecd",
      "Escrow" => "0xddc9821c93203d00a264514888de01fc1129dbff",
      "Exchange" => "0x190480908c11efca37edea4405f4ce1703b68b23",
      "ExchangeEUR" => "0xc200cd8ac71a63e38646c34b51ee3cba159db544",
      "FeeCurrencyWhitelist" => "0x14d449ef428e679da48b3e8cffa9036ff404b28a",
      "Freezer" => "0x3f155cd55697c44fb6e4e0cb7d885faeae38b62d",
      "GasPriceMinimum" => "0xa701fa0b85d935790984ddf3a3ef5597848e1a5f",
      "GoldToken" => "0xddc9be57f553fe75752d61606b94cbd7e0264ef8",
      "Governance" => "0x28443b1d87db521320a6517a4f1b6ead77f8c811",
      "GovernanceApproverMultiSig" => "0x0000000000000000000000000000000000000000",
      "GovernanceSlasher" => "0xee8b4e865ad8b6d93d8b815d8943ad0e04a0f8f9",
      "GrandaMento" => "0x0000000000000000000000000000000000000000",
      "LockedGold" => "0xf07406d8040fbd831e9983ca9cc278fbffeb56bf",
      "Random" => "0x3fcecdaff7c2d48ea73fbf338e99e375a3d6754f",
      "Reserve" => "0x68dd816611d3de196fdeb87438b74a9c29fd649f",
      "ReserveSpenderMultiSig" => "0x0000000000000000000000000000000000000000",
      "SortedOracles" => "0x88a187a876290e9843175027902b9f7f1b092c88",
      "StableToken" => "0x62492a644a588fd904270bed06ad52b9abfea1ae",
      "StableTokenEUR" => "0xf9ece301247ad2ce21894941830a2470f4e774ca",
      "TransferWhitelist" => "0x4bb0805692a74dd0815e11fc1a66441c65f5b5d9",
      "Validators" => "0xcb3a2f0520edbb4fc37ecb646d06877e339bbc9d"
    }
  end

  defp cache(:alfajores) do
    %{
      "Accounts" => "0xed7f51a34b4e71fbe69b3091fcf879cd14bd73a9",
      "Attestations" => "0xad5e5722427d79dff28a4ab30249729d1f8b4cc0",
      "BlockchainParameters" => "0xe5acbb07b4eed078e39d50f66bf0c80cf1b93abe",
      "DoubleSigningSlasher" => "0x88a4c203c488e8277f583942672e1af77e2b5040",
      "DowntimeSlasher" => "0xf2224c1d7b447d9a43a98cbd82fccc0ef1c11cc5",
      "Election" => "0x1c3edf937cfc2f6f51784d20deb1af1f9a8655fa",
      "EpochRewards" => "0xb10ee11244526b94879e1956745ba2e35ae2ba20",
      "Escrow" => "0xb07e10c5837c282209c6b9b3de0edbef16319a37",
      "Exchange" => "0x17bc3304f94c85618c46d0888aa937148007bd3c",
      "ExchangeEUR" => "0x997b494f17d3c49e66fafb50f37a972d8db9325b",
      "ExchangeBRL" => "0xf391dcaf77360d39e566b93c8c0ceb7128fa1a08",
      "FeeCurrencyWhitelist" => "0xb8641365dbe943bc2fb6977e6fbc1630ef47db5a",
      "Freezer" => "0xfe0ada6e9a7b782f55750428cc1d8428cd83c3f1",
      "GasPriceMinimum" => "0xd0bf87a5936ee17014a057143a494dc5c5d51e5e",
      "GoldToken" => "0xf194afdf50b03e69bd7d057c1aa9e10c9954e4c9",
      "Governance" => "0xaa963fc97281d9632d96700ab62a4d1340f9a28a",
      "GovernanceApproverMultiSig" => "0x0000000000000000000000000000000000000000",
      "GovernanceSlasher" => "0x34417682750340ad5a91d1fc306cba430f3071eb",
      "GrandaMento" => "0xecf09fcd57b0c8b1fd3de92d59e234b88938485b",
      "LockedGold" => "0x6a4cc5693dc5bfa3799c699f3b941ba2cb00c341",
      "Random" => "0xdd318eef001bb0867cd5c134496d6cf5aa32311f",
      "Reserve" => "0xa7ed835288aa4524bb6c73dd23c0bf4315d9fe3e",
      "ReserveSpenderMultiSig" => "0x0000000000000000000000000000000000000000",
      "SortedOracles" => "0xfdd8bd58115ffbf04e47411c1d228ecc45e93075",
      "StableToken" => "0x874069fa1eb16d44d622f2e0ca25eea172369bc1",
      "StableTokenEUR" => "0x10c892a6ec43a53e45d0b916b4b7d383b1b78c0f",
      "StableTokenBRL" => "0xe4d517785d091d3c54818832db6094bcc2744545",
      "TransferWhitelist" => "0x52449a99e3455acb831c0d580dcdac8b290d5182",
      "Validators" => "0x9acf2a99914e083ad0d610672e93d14b0736bbcc"
    }
  end
end
