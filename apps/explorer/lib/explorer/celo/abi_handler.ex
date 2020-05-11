defmodule Explorer.Celo.AbiHandler do
  @moduledoc """
  Caching the Celo contract ABIs
  """

  use GenServer

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    contract_abi =
      abi("lockedgold.json") ++
        abi("validators.json") ++
        abi("election.json") ++
        abi("accounts.json") ++
        abi("blockchainparameters.json") ++
        abi("epochrewards.json") ++
        abi("registry.json") ++
        abi("erc20.json")

    {:ok, contract_abi}
  end

  def get_abi do
    GenServer.call(__MODULE__, :fetch)
  end

  @impl GenServer
  def handle_call(:fetch, _, state) do
    {:reply, state, state}
  end

  # sobelow_skip ["Traversal"]
  defp abi(file_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/celo/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
