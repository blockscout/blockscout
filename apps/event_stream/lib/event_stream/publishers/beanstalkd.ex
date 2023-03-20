defmodule EventStream.Publisher.Beanstalkd do
  @moduledoc "Publisher implementation for beanstalkd messaging queue."

  alias EventStream.Publisher
  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub
  @behaviour Publisher
  require Logger

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # charlist required instead of string due to erlang lib quirk
    host = opts |> Keyword.fetch!(:host) |> to_charlist()
    tube = Keyword.get(opts, :tube, "default")
    port = Keyword.get(opts, :port, 11300)

    state = %{
      beanstalk: %{
        host: host,
        tube: tube,
        port: port
      }
    }

    {:ok, state, {:continue, :connect_beanstalk}}
  end

  @impl true
  def handle_continue(
        :connect_beanstalk,
        %{beanstalk: %{host: host, port: port, tube: tube}} = state
      ) do
    Logger.info("Connecting to beanstalkd on #{host |> to_string()}:#{port |> to_string()}...")
    {:ok, pid} = ElixirTalk.connect(host, port)

    Logger.info("Connected, using tube #{tube}")
    {:using, ^tube} = ElixirTalk.use(pid, tube)

    {:noreply, put_in(state, [:beanstalk, :pid], pid)}
  end

  # disable "explicit try" check
  # credo:disable-for-lines:4
  @impl Publisher
  def publish(event) do
    try do
      GenServer.call(__MODULE__, {:publish, event})
      :ok
    rescue
      error ->
        Logger.error("Error sending event:#{inspect(event)} error:#{inspect(error)}")
        {:failed, event}
    end
  end

  @impl Publisher
  def live do
    with instance <- Process.whereis(__MODULE__),
         result <- GenServer.call(instance, :connected) do
      result
    else
      _error -> false
    end
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @impl true
  def handle_call({:publish, event}, _sender, %{beanstalk: %{pid: pid}} = state) do
    {:inserted, count} = beanstalk_publish(pid, event)
    PubSub.broadcast(EventStream.PubSub, "beanstalkd:published", {event})
    Telemetry.event([:event_stream, :beanstalkd, :publish], %{event_count: count})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _sender, %{beanstalk: %{pid: pid}} = state) do
    beanstalk_stats = ElixirTalk.stats(pid)
    stats_info = Map.put(state, :remote_info, beanstalk_stats)
    {:reply, stats_info, state}
  end

  @impl true
  def handle_call(:connected, _sender, %{beanstalk: beanstalkd} = state) do
    {:reply, Map.has_key?(beanstalkd, :pid), state}
  end

  defp beanstalk_publish(beanstalk_pid, event) do
    ElixirTalk.put(beanstalk_pid, event)
  end
end
