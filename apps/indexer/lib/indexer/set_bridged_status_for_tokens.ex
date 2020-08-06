defmodule Indexer.SetBridgedStatusForTokens do
  @moduledoc """
  Peiodically checks unprocessed tokens and sets bridged status.
  """

  use GenServer

  require Logger

  alias Explorer.Chain

  @interval :timer.minutes(1)

  # def child_spec([init_arguments]) do
  #   child_spec([init_arguments, []])
  # end

  # def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
  #   default = %{
  #     id: __MODULE__,
  #     start: {__MODULE__, :start_link, start_link_arguments}
  #   }

  #   Supervisor.child_spec(default, [])
  # end

  def start_link([init_opts, gen_server_opts]) do
    start_link(init_opts, gen_server_opts)
  end

  def start_link(init_opts, gen_server_opts) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  @impl GenServer
  def init(opts) do
    interval = opts[:interval] || @interval

    Process.send_after(self(), :reveal_unprocessed_tokens, interval)

    {:ok, %{interval: interval}}
  end

  @impl GenServer
  def handle_info(:reveal_unprocessed_tokens, %{interval: interval} = state) do
    Logger.debug(fn -> "Reveal unprocessed tokens" end)

    {:ok, token_addresses} = Chain.unprocessed_token_addresses_to_reveal_bridged_tokens()

    fetch_tokens_bridged_status(token_addresses)

    Process.send_after(self(), :reveal_unprocessed_tokens, interval)

    {:noreply, state}
  end

  defp fetch_tokens_bridged_status(token_addresses) do
    :ok = Chain.fetch_tokens_bridged_status(token_addresses)

    Logger.debug(fn -> "Bridged status fetched for tokens" end)
  end
end
