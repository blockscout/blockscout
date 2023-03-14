defmodule EventStream.Publisher do
  @moduledoc "Representing an instance of where to publish"

  @doc """
  Fetch a contract address for a given name
  """
  @callback publish(String.t()) :: :ok | {:failed, String.t()}

  @callback live() :: boolean

  def publish(event) do
    implementation = Application.get_env(:event_stream, __MODULE__)
    implementation.publish(event)
  end

  def connected? do
    implementation = Application.get_env(:event_stream, __MODULE__)
    implementation.live()
  end
end
