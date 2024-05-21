defmodule Explorer.Init.DefaultTransaction do
  @moduledoc """
  The module that defines the default transaction hash for the GraphQL.
  """

  use GenServer

  alias Explorer.Application.Constants
  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Repo

  require Logger

  import Ecto.Query,
    only: [
      limit: 2,
      select: 3
    ]

  @interval :timer.seconds(10)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Process.send_after(self(), :import, @interval)

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:import, state) do
    Logger.debug(fn -> "Importing default transaction hash" end)
    cached_default_transaction_hash = Constants.get_default_transaction_hash()

    if cached_default_transaction_hash do
      Logger.debug(fn -> "Default transaction hash is already set" end)
    else
      Logger.debug(fn -> "Setting default transaction hash" end)
      transaction_hash = get_arbitrary_transaction_hash()
      Constants.set_constant_value("default_transaction_hash", Hash.to_string(transaction_hash))
    end

    {:noreply, state}
  end

  defp get_arbitrary_transaction_hash do
    Transaction
    |> select([transaction], transaction.hash)
    |> limit(1)
    |> Repo.one()
  end
end
