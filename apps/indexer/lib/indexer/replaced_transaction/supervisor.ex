defmodule Indexer.ReplacedTransaction.Supervisor do
  @moduledoc """
  Supervises `Indexer.ReplacedTransaction.Fetcher` and its batch tasks through
  `Indexer.ReplacedTransaction.TaskSupervisor`.
  """

  use Supervisor

  alias Indexer.ReplacedTransaction.Fetcher

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(arguments, gen_server_options \\ []) do
    if disabled?() do
      :ignore
    else
      Supervisor.start_link(__MODULE__, arguments, Keyword.put_new(gen_server_options, :name, __MODULE__))
    end
  end

  def disabled?() do
    Application.get_env(:indexer, __MODULE__, [])[:disabled?] == true
  end

  @impl Supervisor
  def init(fetcher_arguments) do
    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.ReplacedTransaction.TaskSupervisor},
        {Fetcher, [fetcher_arguments, [name: Fetcher]]}
      ],
      strategy: :one_for_one
    )
  end
end
