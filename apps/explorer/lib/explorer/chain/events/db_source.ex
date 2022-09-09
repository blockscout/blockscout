defmodule Explorer.Chain.Events.DBSource do
  @moduledoc "Source of chain events via pg_notify"

  alias Postgrex.Notifications

  @channel "chain_event"

  def setup_source do
    {:ok, pid} =
      :explorer
      |> Application.get_env(Explorer.Repo)
      |> Notifications.start_link()

    ref = Notifications.listen!(pid, @channel)

    %{dbsource_pid: pid, channel_ref: ref}
  end

  def handle_source_msg({:notification, _pid, _ref, _topic, payload}) do
    payload
    |> decode_payload!()
  end

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_payload!(payload) do
    payload
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
end
