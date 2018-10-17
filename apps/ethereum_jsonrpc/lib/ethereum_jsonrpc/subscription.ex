defmodule EthereumJSONRPC.Subscription do
  @moduledoc """
  A subscription to an event
  """

  alias EthereumJSONRPC.Transport

  @enforce_keys ~w(reference subscriber_pid transport transport_options)a
  defstruct ~w(reference subscriber_pid transport transport_options)a

  @typedoc """
  An event that can be subscribed to.

   * `"newHeads"` - when new blocks are added to chain including during reorgs.
  """
  @type event :: String.t()

  @typedoc """
  Subscription ID returned from `eth_subscribe` and used to canceled a subscription with `eth_unsubscribe`.
  """
  @type id :: String.t()

  @typedoc """
  Parameters for customizing subscription to `t:event/0`.
  """
  @type params :: list()

  @typedoc """
   * `reference` - the `t:reference/0` for referring to the subscription when talking to `transport_pid`.
   * `subscriber_pid` - the `t:pid/0` of process where `transport_pid` should send messages.
   * `transport` - the `t:EthereumJSONRPC.Transport.t/0` callback module.
   * `transport_options` - options passed to `c:EthereumJSONRPC.Transport.json_rpc/2`.
  """
  @type t :: %__MODULE__{
          reference: reference(),
          subscriber_pid: pid(),
          transport: Transport.t(),
          transport_options: Transport.options()
        }

  @doc """
  Publishes `messages` to all `subscriptions`s' `subscriber_pid`s.

  Sends `message` tagged with each `subscription`: `{subscription, message}`.
  """
  @spec broadcast(Enumerable.t(), message :: term()) :: :ok
  def broadcast(subscriptions, message) do
    Enum.each(subscriptions, &publish(&1, message))
  end

  @doc """
  Publishes `message` to the `subscription`'s `subscriber_pid`.

  Sends `message` tagged with `subscription`: `{subscription, message}`.
  """
  @spec publish(t(), message :: term()) :: :ok
  def publish(%__MODULE__{subscriber_pid: subscriber_pid} = subscription, message) do
    send(subscriber_pid, subscription_message(subscription, message))
  end

  defp subscription_message(%__MODULE__{} = subscription, message) do
    {subscription, message}
  end
end
