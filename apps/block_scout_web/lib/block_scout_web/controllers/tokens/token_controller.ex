defmodule BlockScoutWeb.Tokens.TokenController do
  use BlockScoutWeb, :controller

  require Logger

  alias Explorer.Chain

  def show(conn, %{"id" => address_hash_string}) do
    redirect(conn, to: token_transfer_path(conn, :index, address_hash_string))
  end

  def fetch_token_counters(token, address_hash) do
    total_token_transfers_task =
      Task.async(fn ->
        Chain.count_token_transfers_from_token_hash(address_hash)
      end)

    total_token_holders_task =
      Task.async(fn ->
        token.holder_count || Chain.count_token_holders_from_token_hash(address_hash)
      end)

    [total_token_transfers_task, total_token_holders_task]
    |> Task.yield_many(:timer.seconds(40))
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
