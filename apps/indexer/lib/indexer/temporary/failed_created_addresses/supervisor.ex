defmodule Indexer.Temporary.FailedCreatedAddresses.Supervisor do
  @moduledoc """
  Supervises `Indexer.Temporary.FailedCreatedAddresses`.
  """

  use Supervisor

  alias Indexer.Temporary.FailedCreatedAddresses

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

  def start_link(json_rpc_named_arguments, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, json_rpc_named_arguments, gen_server_options)
  end

  @impl Supervisor
  def init(json_rpc_named_arguments) do
    Supervisor.init(
      [
        {Task.Supervisor, name: Indexer.Temporary.FailedCreatedAddresses.TaskSupervisor},
        {FailedCreatedAddresses, [json_rpc_named_arguments, [name: FailedCreatedAddresses]]}
      ],
      strategy: :rest_for_one
    )
  end
end
