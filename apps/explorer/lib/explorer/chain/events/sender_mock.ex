defmodule Explorer.Chain.Events.SenderMock do
  @moduledoc """
  Sends events directly to Listener.
  """
  alias Explorer.Chain.Events.Listener

  def send_notify(payload) do
    send(Listener, {:notification, nil, nil, nil, payload})
  end
end
