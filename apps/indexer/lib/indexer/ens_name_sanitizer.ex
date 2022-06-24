defmodule Indexer.ENSNameSanitizer do
  @moduledoc """
  Periodically checks ENS names for transfers and address changes.
  Purges such names from database.
  """

  use GenServer

  require Logger

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address
  alias Explorer.ENS.NameRetriever
  import Ecto.Query, only: [from: 2]

  @interval :timer.hours(1)

  defstruct interval: @interval,
            json_rpc_named_arguments: []

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def init(opts) when is_list(opts) do
    state = %__MODULE__{
      json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
      interval: opts[:interval] || @interval
    }

    if enabled() do
      Process.send_after(self(), :sanitize_ens_names, state.interval)
    end

    {:ok, state}
  end

  def handle_info(
        :sanitize_ens_names,
        %{interval: interval} = state
      ) do
    Logger.info("Start sanitizing of ens names",
      fetcher: :address_names
    )

    sanitize_ens_names()

    Process.send_after(self(), :sanitize_ens_names, interval)

    {:noreply, state}
  end

  defp sanitize_ens_names do
    name_list_from_db = Chain.ens_name_list()

    deleted_counts =
      name_list_from_db
      |> Enum.map(fn name ->
        address_hash =
          case NameRetriever.fetch_address_of(name.name) do
            {:ok, address} ->
              {:ok, hash} = Chain.string_to_address_hash(address)
              hash

            {:error, _message} ->
              {:ok, hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
              hash
          end

        if address_hash != name.address_hash do
          delete_query =
            from(
              address_name in Address.Name,
              where: address_name.address_hash == ^name.address_hash,
              where: address_name.name == ^name.name
            )

          {count, _deleted} = Repo.delete_all(delete_query, [])
          count
        else
          0
        end
      end)

    Logger.info(
      "ENS names are sanitized. Total: #{Enum.count(name_list_from_db)}, dropped: #{Enum.sum(deleted_counts)}",
      fetcher: :address_names
    )
  end

  defp enabled do
    Application.get_env(:indexer, Indexer.Fetcher.ENSName.Supervisor)
    |> Keyword.get(:disabled?) == false
  end
end
