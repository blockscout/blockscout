defmodule Indexer.Fetcher.AddressImporter do
  @moduledoc """
  Periodically updates addresses accumulated from block fetcher
  """

  use GenServer

  require Logger

  alias Explorer.Chain
  alias Indexer.Block.Fetcher

  @default_update_interval :timer.minutes(1)

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: Application.get_env(:indexer, :graceful_shutdown_period)
    }
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_update()

    {:ok, %{}}
  end

  def add(addresses_params) do
    GenServer.cast(__MODULE__, {:add, addresses_params})
  end

  def handle_cast({:add, addresses_params}, state) do
    params_map = Map.new(addresses_params, fn address -> {address.hash, address} end)

    result_state =
      Map.merge(state, params_map, fn _hash, old_address, new_address ->
        old_address
        |> process_contract_code(new_address)
        |> process_fetched_coin_balance_block_number(new_address)
        |> process_nonce(new_address)
      end)

    {:noreply, result_state}
  end

  def handle_info(:update, addresses_map) do
    Logger.info("AddressImporter importing #{Enum.count(addresses_map)} addresses")
    result_state = do_update(addresses_map)
    schedule_next_update()
    {:noreply, result_state}
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      log_error(error)
      schedule_next_update()

      {:noreply, addresses_map}
  end

  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    do_update(state)
  end

  defp do_update(addresses_map) do
    addresses_params = Map.values(addresses_map)

    case Chain.import(%{addresses: %{params: addresses_params}, timeout: :infinity}) do
      {:ok, imported} ->
        address_hash_to_block_number =
          Enum.reduce(addresses_params, %{}, fn
            %{fetched_coin_balance_block_number: block_number, hash: hash}, acc ->
              Map.put(acc, String.downcase(hash), block_number)

            _, acc ->
              acc
          end)

        Fetcher.async_import_coin_balances(imported, %{
          address_hash_to_fetched_balance_block_number: address_hash_to_block_number
        })

        Fetcher.async_import_filecoin_addresses_info(imported, false)
        Logger.info("AddressImporter imported #{Enum.count(addresses_map)} addresses")

        %{}

      error ->
        log_error(inspect(error))
        addresses_map
    end
  end

  defp process_contract_code(old_address, %{contract_code: contract_code}) when not is_nil(contract_code) do
    Map.put(old_address, :contract_code, contract_code)
  end

  defp process_contract_code(old_address, _new_address), do: old_address

  defp process_fetched_coin_balance_block_number(old_address, new_address) do
    old_block_number = old_address[:fetched_coin_balance_block_number]
    new_block_number = new_address[:fetched_coin_balance_block_number]

    if not is_nil(new_block_number) and (is_nil(old_block_number) or new_block_number >= old_block_number) do
      Map.put(old_address, :fetched_coin_balance_block_number, new_block_number)
    else
      old_address
    end
  end

  defp process_nonce(old_address, new_address) do
    old_nonce = old_address[:nonce]
    new_nonce = new_address[:nonce]

    if not is_nil(new_nonce) and (is_nil(old_nonce) or new_nonce > old_nonce) do
      Map.put(old_address, :nonce, new_nonce)
    else
      old_address
    end
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @default_update_interval)
  end

  defp log_error(error) do
    Logger.error("Failed to update addresses: #{error}, retrying")
  end
end
