defmodule Indexer.Temporary.InternalTransactionsBlockHash.Supervisor do
  @moduledoc """
  Supervises `Indexer.Temporary.InternalTransactionsBlockHash`.
  """

  use Supervisor

  alias Indexer.Temporary.InternalTransactionsBlockHash

  def child_spec do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_arguments \\ [], gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, init_arguments, gen_server_options)
  end

  @impl Supervisor
  def init(_) do
    Supervisor.init(
      [
        {InternalTransactionsBlockHash, [name: InternalTransactionsBlockHash]}
      ],
      strategy: :rest_for_one
    )
  end
end
