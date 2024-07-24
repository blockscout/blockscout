defmodule Explorer.SmartContract.CertifiedSmartContractCataloger do
  @moduledoc """
  Actualizes certified smart-contracts.
  """

  use GenServer, restart: :transient

  alias Explorer.Chain.SmartContract

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    send(self(), :fetch_certified_smart_contracts)

    {:ok, args}
  end

  @impl GenServer
  def handle_info(:fetch_certified_smart_contracts, state) do
    certified_contracts_list = Application.get_env(:block_scout_web, :contract)[:certified_list]

    SmartContract.set_smart_contracts_certified_flag(certified_contracts_list)

    {:noreply, state}
  end
end
