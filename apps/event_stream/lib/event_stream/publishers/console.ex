defmodule EventStream.Publisher.Console do
  @moduledoc "Just writing events to the console"

  alias EventStream.Publisher
  @behaviour Publisher
  require Logger

  @impl Publisher
  def publish(event) do
    event
    |> inspect()
    |> then(&Logger.info("Event to send: #{&1}"))
  end
end
