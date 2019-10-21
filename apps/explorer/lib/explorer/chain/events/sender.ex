defmodule Explorer.Chain.Events.Sender do
  @moduledoc """
  Sends events to Postgres.
  """
  alias Explorer.Repo

  @callback send_notify(String.t()) :: {:ok, any}

  def send_notify(payload) do
    Repo.query!("select pg_notify('chain_event', $1::text);", [payload])
  end
end
