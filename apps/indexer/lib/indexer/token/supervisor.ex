defmodule Indexer.Token.Supervisor do
  @moduledoc """
  Supervises `Indexer.Token.Fetcher` and its batch tasks through `Indexer.Token.TaskSupervisor`.
  """

  use Supervisor

  alias Indexer.Token.{Fetcher, MetadataUpdater}

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
    Supervisor.start_link(__MODULE__, arguments, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl Supervisor
  def init(fetcher_arguments) do
    metadata_updater_inverval = Application.get_env(:indexer, :metadata_updater_days_interval)

    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.Token.TaskSupervisor},
        {Fetcher, [fetcher_arguments, [name: Fetcher]]},
        {MetadataUpdater, %{update_interval: metadata_updater_inverval}}
      ],
      strategy: :one_for_one
    )
  end
end
