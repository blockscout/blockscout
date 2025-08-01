defmodule Explorer.Chain.Fetcher.CheckBytecodeMatchingOnDemand do
  @moduledoc """
    On demand checker if bytecode written in BlockScout's DB equals to bytecode stored on node (only for verified contracts)
  """

  use GenServer

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Repo
  alias Explorer.Utility.RateLimiter

  # seconds
  @check_bytecode_interval 86_400

  def trigger_check(caller \\ nil, address, smart_contract)

  def trigger_check(_caller, _address, %NotLoaded{}) do
    :ignore
  end

  def trigger_check(caller, address, _) do
    case RateLimiter.check_rate(caller, :on_demand) do
      :allow -> GenServer.cast(__MODULE__, {:check, address})
      :deny -> :ok
    end
  end

  defp check_bytecode_matching(address) do
    now = DateTime.utc_now()
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    with true <-
           !address.smart_contract.is_changed_bytecode and
             address.smart_contract.bytecode_checked_at
             |> DateTime.add(@check_bytecode_interval, :second)
             |> DateTime.compare(now) != :gt,
         {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} <-
           EthereumJSONRPC.fetch_codes(
             [%{block_quantity: "latest", address: address.smart_contract.address_hash}],
             json_rpc_named_arguments
           ),
         bytecode_from_node <- fetched_codes |> List.first() |> Map.get(:code),
         bytecode_from_db <- "0x" <> (address.contract_code.bytes |> Base.encode16(case: :lower)),
         {:changed, true} <- {:changed, bytecode_from_node == bytecode_from_db} do
      {:ok, _} =
        address.smart_contract
        |> Changeset.change(%{bytecode_checked_at: now})
        |> Repo.update()
    else
      {:changed, false} ->
        Publisher.broadcast(%{changed_bytecode: [address.smart_contract.address_hash]}, :on_demand)

        {:ok, _} =
          address.smart_contract
          |> Changeset.change(%{bytecode_checked_at: now, is_changed_bytecode: true})
          |> Repo.update()

      _ ->
        nil
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_cast({:check, address}, state) do
    check_bytecode_matching(address)

    {:noreply, state}
  end
end
