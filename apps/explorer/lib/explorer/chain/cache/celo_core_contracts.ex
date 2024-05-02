defmodule Explorer.Chain.Cache.CeloCoreContracts do
  @moduledoc """
  Cache for Celo core contract addresses.
  """

  require Logger

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.SmartContract.Reader

  use Explorer.Chain.MapCache,
    name: :celo_core_contracts,
    key: :contract_addresses,
    key: :async_task,
    global_ttl: :timer.minutes(60),
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  @registry_proxy_contract_address "0x000000000000000000000000000000000000ce10"

  @get_implementation_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "_getImplementation",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "implementation",
          "type" => "address"
        }
      ],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # 42404e07 = keccak(_getImplementation())
  @get_implementation_signature "42404e07"

  @get_address_for_string_abi [
    %{
      "constant" => true,
      "inputs" => [%{"name" => "identifier", "type" => "string"}],
      "name" => "getAddressForString",
      "outputs" => [%{"name" => "", "type" => "address"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # 853db323 = keccak(getAddressForString(string))
  @get_address_for_string_signature "853db323"

  @contract_atoms [
    :accounts,
    :celo_token,
    :election,
    :epoch_rewards,
    :locked_gold,
    :reserve,
    :usd_token
  ]

  def get_address(contract_atom) when contract_atom in @contract_atoms do
    get_contract_addresses()[contract_atom]
  end

  defp default_addresses do
    case Application.get_env(:explorer, __MODULE__)[:celo_network] do
      "mainnet" ->
        %{
          accounts: "",
          celo_token: "0x471ece3750da237f93b8e339c536989b8978a438",
          election: "0x8d6677192144292870907e3fa8a5527fe55a7ff6",
          epoch_rewards: "0x07f007d389883622ef8d4d347b3f78007f28d8b7",
          locked_gold: "0x6cc083aed9e3ebe302a6336dbc7c921c9f03349e",
          reserve: "0x9380fa34fd9e4fd14c06305fd7b6199089ed4eb9",
          usd_token: "0x765de816845861e75a25fca122bb6898b8b1282a"
        }

      "baklava" ->
        %{
          accounts: "",
          celo_token: "0xddc9be57f553fe75752d61606b94cbd7e0264ef8",
          election: "0x7eb2b2f696c60a48afd7632f280c7de91c8e5aa5",
          epoch_rewards: "0xfdc7d3da53ca155ddce793b0de46f4c29230eecd",
          locked_gold: "0xf07406d8040fbd831e9983ca9cc278fbffeb56bf",
          reserve: "0x68dd816611d3de196fdeb87438b74a9c29fd649f",
          usd_token: "0x62492a644a588fd904270bed06ad52b9abfea1ae"
        }

      "alfajores" ->
        %{
          accounts: "",
          celo_token: "0xf194afdf50b03e69bd7d057c1aa9e10c9954e4c9",
          election: "0x1c3edf937cfc2f6f51784d20deb1af1f9a8655fa",
          epoch_rewards: "0xb10ee11244526b94879e1956745ba2e35ae2ba20",
          locked_gold: "0x6a4cc5693dc5bfa3799c699f3b941ba2cb00c341",
          reserve: "0xa7ed835288aa4524bb6c73dd23c0bf4315d9fe3e",
          usd_token: "0x874069fa1eb16d44d622f2e0ca25eea172369bc1"
        }

      _ ->
        nil
    end
  end

  defp handle_fallback(:contract_addresses) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition

    # warn: uncomment
    # get_async_task()

    {:return, default_addresses()}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          nil_address = burn_address_hash_string()

          {failed_contracts, contracts} =
            fetch_core_contract_addresses()
            |> Enum.split_with(fn {_, %{address: address}} -> address in [nil, nil_address] end)

          failed_contracts
          |> Enum.each(fn
            {atom, %{address: ^nil_address}} ->
              Logger.warning("Celo Registry returned address #{nil_address} for contract #{atom}")

            {atom, %{address: nil}} ->
              Logger.error("Could not fetch address for contract #{atom}")
          end)

          contracts
          |> Enum.map(fn
            {atom, %{address: address}} ->
              {atom, address}
          end)
          |> Enum.into(get_contract_addresses())
          |> set_contract_addresses()
        rescue
          e ->
            Logger.error([
              "Could not update Celo core contract addresses",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  def fetch_core_contract_addresses do
    @contract_atoms
    |> Enum.map(fn atom ->
      name = to_contract_name(atom)
      {atom, %{name: name, address: fetch_address_for_contract_name(name)}}
    end)
    |> Enum.into(%{})
  end

  def fetch_address_for_contract_name(contract_name) do
    with %{@get_implementation_signature => {:ok, [implementation_address]}} <-
           Reader.query_contract(
             @registry_proxy_contract_address,
             @get_implementation_abi,
             %{@get_implementation_signature => []},
             false
           ),
         %{@get_address_for_string_signature => {:ok, [contract_address]}} <-
           Reader.query_contract(
             implementation_address,
             @get_address_for_string_abi,
             %{@get_address_for_string_signature => [contract_name]},
             false
           ) do
      contract_address
    else
      _ -> nil
    end
  end

  defp to_contract_name(contract) do
    case contract do
      :accounts -> "Accounts"
      :celo_token -> "GoldToken"
      :election -> "Election"
      :epoch_rewards -> "EpochRewards"
      :locked_gold -> "LockedGold"
      :reserve -> "Reserve"
      :usd_token -> "StableToken"
      _ -> nil
    end
  end

  # By setting this as a `callback` an async task will be started each time the
  # `gas_prices` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :contract_addresses}) do
    get_async_task()
  end

  defp async_task_on_deletion(_data), do: nil
end
