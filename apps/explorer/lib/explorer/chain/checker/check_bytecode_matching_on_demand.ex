defmodule Explorer.Chain.Checker.CheckBytecodeMatchingOnDemand do
  @moduledoc """
    On demand checker if bytecode written in BlockScout's DB equals to bytecode stored on node (only for verified contracts)
  """

  use GenServer

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Explorer.Repo
  alias Explorer.Counters.Helper

  require Logger

  # seconds
  @check_bytecode_interval 86_400

  # cache needed to keep track of transactions which are already being processed
  @cache_name :bytecode_matching_processing

  def trigger_check(_address, %NotLoaded{}) do
    :ignore
  end

  def trigger_check(address, _) do
    GenServer.cast(__MODULE__, {:check, address})
  end

  defp check_bytecode_matching(address) do
    now = DateTime.utc_now()
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    if !address.smart_contract.is_changed_bytecode and
         address.smart_contract.bytecode_checked_at
         |> DateTime.add(@check_bytecode_interval, :second)
         |> DateTime.compare(now) != :gt do
      case EthereumJSONRPC.fetch_codes(
             [%{block_quantity: "latest", address: address.smart_contract.address_hash}],
             json_rpc_named_arguments
           ) do
        {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} ->
          bytecode_from_node = fetched_codes |> List.first() |> Map.get(:code)
          bytecode_from_db = "0x" <> (address.contract_code.bytes |> Base.encode16(case: :lower))

          if bytecode_from_node == bytecode_from_db do
            {:ok, _} =
              address.smart_contract
              |> Changeset.change(%{bytecode_checked_at: now})
              |> Repo.update()

            :ok
          else
            {:ok, _} =
              address.smart_contract
              |> Changeset.change(%{bytecode_checked_at: now, is_changed_bytecode: true})
              |> Repo.update()

            :changed
          end

        _ ->
          :error
      end
    end

    :ets.delete(@cache_name, to_string(address.hash))
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Helper.create_cache_table(@cache_name)

    {:ok, opts}
  end

  @impl true
  def handle_cast({:check, address}, state) do
    hash_string = to_string(address.hash)

    case Helper.fetch_from_cache(hash_string, @cache_name) do
      0 ->
        :ets.insert(@cache_name, {hash_string, 1})
        check_bytecode_matching(address)

      1 ->
        :ignore
    end

    {:noreply, state}
  end
end
