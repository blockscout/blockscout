defmodule Indexer.Fetcher.Optimism.DisputeGame do
  @moduledoc """
  Fills op_dispute_games DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  alias ABI.TypeEncoder
  alias EthereumJSONRPC.Contract
  alias Explorer.Application.Constants
  alias Explorer.{Chain, Helper, Repo}
  alias Explorer.Chain.Data
  alias Explorer.Chain.Hash.Address
  alias Explorer.Chain.Optimism.{DisputeGame, Withdrawal}
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper, as: IndexerHelper

  @fetcher_name :optimism_dispute_games
  @game_check_interval 60
  @games_range_size 50

  @extra_data_method_signature "0x609d3334"
  @resolved_at_method_signature "0x19effeb4"
  @status_method_signature "0x200d2ed2"

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(:ok, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[Optimism]
    system_config = env[:optimism_l1_system_config]
    rpc = env[:optimism_l1_rpc]

    with {:system_config_valid, true} <- {:system_config_valid, IndexerHelper.address_correct?(system_config)},
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(rpc)},
         json_rpc_named_arguments = IndexerHelper.json_rpc_named_arguments(rpc),
         {optimism_portal, _} <- Optimism.read_system_config(system_config, json_rpc_named_arguments),
         dispute_game_factory = get_dispute_game_factory_address(optimism_portal, json_rpc_named_arguments),
         {:dispute_game_factory_available, true} <- {:dispute_game_factory_available, !is_nil(dispute_game_factory)},
         game_count = get_game_count(dispute_game_factory, json_rpc_named_arguments),
         {:game_count_available, true} <- {:game_count_available, !is_nil(game_count)} do
      set_dispute_game_finality_delay_seconds(optimism_portal, json_rpc_named_arguments)
      set_proof_maturity_delay_seconds(optimism_portal, json_rpc_named_arguments)

      Process.send(self(), :continue, [])

      last_known_index = DisputeGame.get_last_known_index()
      end_index = game_count - 1

      {:noreply,
       %{
         dispute_game_factory: dispute_game_factory,
         optimism_portal: optimism_portal,
         start_index: get_start_index(last_known_index, end_index),
         end_index: end_index,
         json_rpc_named_arguments: json_rpc_named_arguments
       }}
    else
      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:system_config_valid, false} ->
        Logger.error("SystemConfig contract address is invalid or undefined.")
        {:stop, :normal, %{}}

      {:dispute_game_factory_available, false} ->
        Logger.error(
          "Cannot get DisputeGameFactory contract address from the OptimismPortal contract. Probably, this is the first implementation of OptimismPortal."
        )

        {:stop, :normal, %{}}

      {:game_count_available, false} ->
        Logger.error("Cannot read gameCount() public getter from the DisputeGameFactory contract.")
        {:stop, :normal, %{}}

      nil ->
        Logger.error("Cannot read SystemConfig contract.")
        {:stop, :normal, %{}}
    end
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          dispute_game_factory: dispute_game_factory,
          optimism_portal: optimism_portal,
          start_index: start_index,
          end_index: end_index,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    time_before = Timex.now()

    update_respected_game_type(optimism_portal, json_rpc_named_arguments)

    chunks_number = ceil((end_index - start_index + 1) / @games_range_size)
    chunk_range = Range.new(0, max(chunks_number - 1, 0), 1)

    chunk_range
    |> Enum.each(fn current_chunk ->
      chunk_start = start_index + @games_range_size * current_chunk
      chunk_end = min(chunk_start + @games_range_size - 1, end_index)

      if chunk_end >= chunk_start do
        log_games_chunk_handling(chunk_start, chunk_end, start_index, end_index, nil)

        games = read_game_list(chunk_start, chunk_end, dispute_game_factory, json_rpc_named_arguments)

        {:ok, _} =
          Chain.import(%{
            optimism_dispute_games: %{params: games},
            timeout: :infinity
          })

        log_games_chunk_handling(chunk_start, chunk_end, start_index, end_index, "#{Enum.count(games)} dispute game(s)")
      end
    end)

    game_count = get_game_count(dispute_game_factory, json_rpc_named_arguments, IndexerHelper.infinite_retries_number())

    false = is_nil(game_count)

    new_end_index = game_count - 1

    Logger.info("Found #{new_end_index - end_index} new game(s) since the last games filling.")

    update_game_statuses(json_rpc_named_arguments)

    delay =
      if new_end_index == end_index do
        # there are no new games, so wait for @game_check_interval seconds to let the new game appear
        max(@game_check_interval * 1000 - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_index: get_start_index(end_index, new_end_index), end_index: new_end_index}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp set_dispute_game_finality_delay_seconds(optimism_portal, json_rpc_named_arguments) do
    set_constant_value(
      "0x952b2797",
      "disputeGameFinalityDelaySeconds()",
      optimism_portal,
      "OptimismPortal",
      Withdrawal.dispute_game_finality_delay_seconds_constant(),
      json_rpc_named_arguments
    )
  end

  defp set_proof_maturity_delay_seconds(optimism_portal, json_rpc_named_arguments) do
    set_constant_value(
      "0xbf653a5c",
      "proofMaturityDelaySeconds()",
      optimism_portal,
      "OptimismPortal",
      Withdrawal.proof_maturity_delay_seconds_constant(),
      json_rpc_named_arguments
    )
  end

  defp update_respected_game_type(optimism_portal, json_rpc_named_arguments) do
    set_constant_value(
      "0x3c9f397c",
      "respectedGameType()",
      optimism_portal,
      "OptimismPortal",
      "optimism_respected_game_type",
      json_rpc_named_arguments
    )
  end

  defp update_game_statuses(json_rpc_named_arguments) do
    query =
      from(
        game in DisputeGame,
        select: %{index: game.index, address_hash: game.address_hash},
        where: is_nil(game.resolved_at),
        order_by: [desc: game.index],
        limit: 1000
      )

    update_count =
      query
      |> Repo.all(timeout: :infinity)
      |> Enum.chunk_every(@games_range_size)
      |> Enum.reduce(0, fn games_chunk, update_count_acc ->
        resolved_at_by_index =
          read_extra_data(@resolved_at_method_signature, "resolvedAt()", games_chunk, json_rpc_named_arguments)

        games_resolved =
          games_chunk
          |> Enum.filter(fn %{index: index} ->
            resolved_at = quantity_to_integer(resolved_at_by_index[index])
            resolved_at > 0 and not is_nil(resolved_at)
          end)

        status_by_index =
          read_extra_data(@status_method_signature, "status()", games_resolved, json_rpc_named_arguments)

        Enum.reduce(games_resolved, update_count_acc, fn %{index: index}, acc ->
          resolved_at = sanitize_resolved_at(resolved_at_by_index[index])
          status = quantity_to_integer(status_by_index[index])

          {local_update_count, _} =
            Repo.update_all(
              from(game in DisputeGame, where: game.index == ^index),
              set: [resolved_at: resolved_at, status: status]
            )

          acc + local_update_count
        end)
      end)

    if update_count > 0 do
      Logger.info("A new game status for #{update_count} game(s) was set.")
    end
  end

  defp get_dispute_game_factory_address(optimism_portal, json_rpc_named_arguments) do
    req = Contract.eth_call_request("0xf2b4e617", optimism_portal, 0, nil, nil)

    error_message =
      &"Cannot fetch DisputeGameFactory contract address. Probably, this is the first implementation of OptimismPortal. Error: #{inspect(&1)}"

    case IndexerHelper.repeated_call(
           &json_rpc/2,
           [req, json_rpc_named_arguments],
           error_message,
           IndexerHelper.infinite_retries_number()
         ) do
      {:ok, "0x000000000000000000000000" <> address} -> "0x" <> address
      _ -> nil
    end
  end

  defp get_game_count(dispute_game_factory, json_rpc_named_arguments, retries \\ 3) do
    req = Contract.eth_call_request("0x4d1975b4", dispute_game_factory, 0, nil, nil)
    error_message = &"Cannot fetch game count from the DisputeGameFactory contract. Error: #{inspect(&1)}"

    case IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries) do
      {:ok, count} -> quantity_to_integer(count)
      _ -> nil
    end
  end

  defp get_start_index(end_index, new_end_index) do
    if new_end_index < end_index do
      # reorg occurred
      remove_games_after_reorg(new_end_index)
      max(new_end_index, 0)
    else
      end_index + 1
    end
  end

  defp log_games_chunk_handling(chunk_start, chunk_end, start_index, end_index, items_count) do
    is_start = is_nil(items_count)

    {type, found} =
      if is_start do
        {"Start", ""}
      else
        {"Finish", " Handled #{items_count}."}
      end

    target_range =
      if chunk_start != start_index or chunk_end != end_index do
        progress =
          if is_start do
            ""
          else
            percentage =
              (chunk_end - start_index + 1)
              |> Decimal.div(end_index - start_index + 1)
              |> Decimal.mult(100)
              |> Decimal.round(2)
              |> Decimal.to_string()

            " Progress: #{percentage}%"
          end

        " Target range: #{start_index}..#{end_index}.#{progress}"
      else
        ""
      end

    if chunk_start == chunk_end do
      Logger.info("#{type} handling a game ##{chunk_start}.#{found}#{target_range}")
    else
      Logger.info("#{type} handling games #{chunk_start}..#{chunk_end}.#{found}#{target_range}")
    end
  end

  defp read_game_list(start_index, end_index, dispute_game_factory, json_rpc_named_arguments, retries \\ 10) do
    requests =
      start_index..end_index
      |> Enum.map(fn index ->
        encoded_call =
          TypeEncoder.encode([index], %ABI.FunctionSelector{
            function: "gameAtIndex",
            types: [
              {:uint, 256}
            ]
          })

        calldata = %Data{bytes: encoded_call}

        Contract.eth_call_request(calldata, dispute_game_factory, index, nil, nil)
      end)

    error_message = &"Cannot call gameAtIndex() public getter of DisputeGameFactory. Error: #{inspect(&1)}"

    with {:ok, responses} <-
           IndexerHelper.repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, retries),
         games = decode_games(responses),
         extra_data_by_index =
           read_extra_data(@extra_data_method_signature, "extraData()", games, json_rpc_named_arguments),
         false <- is_nil(extra_data_by_index),
         resolved_at_by_index =
           read_extra_data(@resolved_at_method_signature, "resolvedAt()", games, json_rpc_named_arguments),
         false <- is_nil(resolved_at_by_index),
         status_by_index = read_extra_data(@status_method_signature, "status()", games, json_rpc_named_arguments),
         false <- is_nil(status_by_index) do
      Enum.map(games, fn game ->
        [extra_data] = Helper.decode_data(extra_data_by_index[game.index], [:bytes])

        game
        |> Map.put(:extra_data, %Data{bytes: extra_data})
        |> Map.put(:resolved_at, sanitize_resolved_at(resolved_at_by_index[game.index]))
        |> Map.put(:status, quantity_to_integer(status_by_index[game.index]))
      end)
    else
      _ -> []
    end
  end

  defp sanitize_resolved_at(resolved_at) do
    case quantity_to_integer(resolved_at) do
      0 -> nil
      value -> Timex.from_unix(value)
    end
  end

  defp decode_games(responses) do
    responses
    |> Enum.map(fn response ->
      [game_type, created_at, address_hash] = Helper.decode_data(response.result, [{:uint, 32}, {:uint, 64}, :address])

      {:ok, address} = Address.cast(address_hash)

      %{
        index: response.id,
        game_type: game_type,
        address_hash: address,
        created_at: Timex.from_unix(created_at)
      }
    end)
  end

  defp read_extra_data(method_id, method_name, games, json_rpc_named_arguments, retries \\ 10) do
    requests =
      games
      |> Enum.map(&Contract.eth_call_request(method_id, &1.address_hash, &1.index, nil, nil))

    error_message = &"Cannot call #{method_name} public getter of FaultDisputeGame. Error: #{inspect(&1)}"

    case IndexerHelper.repeated_call(&json_rpc/2, [requests, json_rpc_named_arguments], error_message, retries) do
      {:ok, responses} ->
        Enum.reduce(responses, %{}, fn response, acc ->
          game_index = response.id
          data = response.result
          Map.put(acc, game_index, data)
        end)

      _ ->
        nil
    end
  end

  defp remove_games_after_reorg(starting_index) do
    {deleted_count, _} = Repo.delete_all(from(g in DisputeGame, where: g.index >= ^starting_index))

    if deleted_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, all rows with index >= #{starting_index} were removed from the op_dispute_games table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  defp set_constant_value(
         method_id,
         method_name,
         contract_address,
         contract_name,
         constant_name,
         json_rpc_named_arguments
       ) do
    req = Contract.eth_call_request(method_id, contract_address, 0, nil, nil)
    error_message = &"Cannot get #{method_name} from #{contract_name} contract. Error: #{inspect(&1)}"

    case IndexerHelper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, 10) do
      {:ok, value} ->
        Constants.set_constant_value(constant_name, Integer.to_string(quantity_to_integer(value)))

      _ ->
        raise "Cannot get #{method_name} from #{contract_name} contract."
    end
  end
end
