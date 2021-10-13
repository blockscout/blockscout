defmodule BlockScoutWeb.Tokens.TokenController do
  use BlockScoutWeb, :controller

  require Logger

  alias BlockScoutWeb.AccessHelpers
  alias Explorer.Chain
  alias Explorer.Counters.{TokenHoldersCounter, TokenTransfersCounter}

  def show(conn, %{"id" => address_hash_string}) do
    redirect(conn, to: AccessHelpers.get_path(conn, :token_transfer_path, :index, address_hash_string))
  end

  def token_counters(conn, %{"id" => address_hash_string}) do
    case Chain.string_to_address_hash(address_hash_string) do
      {:ok, address_hash} ->
        {transfer_count, token_holder_count} = fetch_token_counters(address_hash, 200)

        json(conn, %{transfer_count: transfer_count, token_holder_count: token_holder_count})

      _ ->
        not_found(conn)
    end
  end

  defp fetch_token_counters(address_hash, timeout) do
    total_token_transfers_task =
      Task.async(fn ->
        TokenTransfersCounter.fetch(address_hash)
      end)

    total_token_holders_task =
      Task.async(fn ->
        TokenHoldersCounter.fetch(address_hash)
      end)

    [total_token_transfers_task, total_token_holders_task]
    |> Task.yield_many(:timer.seconds(timeout))
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          Logger.warn("Query fetching token counters terminated: #{inspect(reason)}")
          0

        nil ->
          Logger.warn("Query fetching token counters timed out.")
          0
      end
    end)
    |> List.to_tuple()
  end
end
