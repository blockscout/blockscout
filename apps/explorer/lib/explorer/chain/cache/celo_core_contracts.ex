defmodule Explorer.Chain.Cache.CeloCoreContracts do
  @moduledoc """
  Cache for Celo core contract addresses.
  """

  require Logger

  # import Ecto.Query,
  #   only: [
  #     from: 2
  #   ]

  alias Explorer.Celo.AbiHandler
  alias Explorer.SmartContract.Reader

  use Explorer.Chain.MapCache,
    name: :celo_core_contracts,
    key: :contract_addresses,
    key: :async_task,
    global_ttl: :timer.minutes(60),
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  @registry_proxy_contract_address "0x000000000000000000000000000000000000ce10"
  @nil_address "0x0000000000000000000000000000000000000000"
  @celo_network System.get_env("CELO_NETWORK") || "mainnet"

  @contract_atoms [
    :celo_token
  ]

  defp default_addresses do
    case @celo_network do
      "mainnet" -> %{celo_token: "0x471ece3750da237f93b8e339c536989b8978a438"}
      "baklava" -> %{celo_token: "0xddc9be57f553fe75752d61606b94cbd7e0264ef8"}
      "alfajores" -> %{celo_token: "0xf194afdf50b03e69bd7d057c1aa9e10c9954e4c9"}
      _ -> nil
    end
  end

  defp handle_fallback(:contract_addresses) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition

    get_async_task()

    {:return, default_addresses()}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          {failed_contracts, contracts} =
            fetch_core_contract_addresses()
            |> Enum.split_with(fn {_, %{address: address}} -> address in [nil, @nil_address] end)

          failed_contracts
          |> Enum.each(fn
            {atom, %{address: @nil_address}} ->
              Logger.warning("Celo Registry returned address #{@nil_address} for contract #{atom}")

            {atom, %{address: nil}} ->
              Logger.error("Could not fetch address for contract #{atom}l")
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
    with abi <- AbiHandler.get_abi(),
         # 42404e07 = keccak(_getImplementation())
         %{"42404e07" => {:ok, [implementation_address]}} <-
           Reader.query_contract(
             @registry_proxy_contract_address,
             abi,
             %{"42404e07" => []},
             false
           ),
         # 853db323 = keccak(getAddressForString(string))
         %{"853db323" => {:ok, [contract_address]}} <-
           Reader.query_contract(
             implementation_address,
             abi,
             %{"853db323" => [contract_name]},
             false
           ) do
      contract_address
    else
      _ -> nil
    end
  end

  defp to_contract_name(contract) do
    case contract do
      :celo_token -> "GoldToken"
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
