defmodule Explorer.TokenInstanceOwnerAddressMigration.Supervisor do
  @moduledoc """
    Supervisor for Explorer.TokenInstanceOwnerAddressMigration.Worker
  """

  use Supervisor

  alias Explorer.TokenInstanceOwnerAddressMigration.Worker

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    params = Application.get_env(:explorer, Explorer.TokenInstanceOwnerAddressMigration)

    if params[:enabled] do
      children = [
        {Worker, params}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      :ignore
    end
  end
end
