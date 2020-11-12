defmodule Explorer.Counters.AverageBlockTime do
  use GenServer

  @moduledoc """
  Caches the number of token holders of a token.
  """

  import Ecto.Query, only: [from: 2, where: 2]

  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Timex.Duration

  @refresh_period Application.get_env(:explorer, __MODULE__)[:period]

  @doc """
  Starts a process to periodically update the counter of the token holders.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def average_block_time do
    enabled? =
      :explorer
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:enabled)

    if enabled? do
      GenServer.call(__MODULE__, :average_block_time)
    else
      {:error, :disabled}
    end
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh_timestamps)
  end

  ## Server
  @impl true
  def init(_) do
    Process.send_after(self(), :refresh_timestamps, @refresh_period)

    {:ok, refresh_timestamps()}
  end

  @impl true
  def handle_call(:average_block_time, _from, %{average: average} = state), do: {:reply, average, state}

  @impl true
  def handle_call(:refresh_timestamps, _, _) do
    {:reply, :ok, refresh_timestamps()}
  end

  @impl true
  def handle_info(:refresh_timestamps, _) do
    Process.send_after(self(), :refresh_timestamps, @refresh_period)

    {:noreply, refresh_timestamps()}
  end

  defp refresh_timestamps do
    base_query =
      from(block in Block,
        limit: 100,
        offset: 100,
        order_by: [desc: block.number],
        select: {block.number, block.timestamp}
      )

    timestamps_query =
      if Application.get_env(:explorer, :include_uncles_in_average_block_time) do
        base_query
      else
        base_query
        |> where(consensus: true)
      end

    timestamps_row =
      timestamps_query
      |> Repo.all()

    timestamps =
      timestamps_row
      |> Enum.sort_by(fn {_, timestamp} -> timestamp end, &>=/2)
      |> Enum.map(fn {number, timestamp} ->
        {number, DateTime.to_unix(timestamp, :millisecond)}
      end)

    %{timestamps: timestamps, average: average_distance(timestamps)}
  end

  defp average_distance([]), do: Duration.from_milliseconds(0)
  defp average_distance([_]), do: Duration.from_milliseconds(0)

  defp average_distance(timestamps) do
    durations = durations(timestamps)

    {sum, count} =
      Enum.reduce(durations, {0, 0}, fn duration, {sum, count} ->
        {sum + duration, count + 1}
      end)

    average = sum / count

    average
    |> round()
    |> Duration.from_milliseconds()
  end

  defp durations(timestamps) do
    timestamps
    |> Enum.reduce({[], nil, nil}, fn {block_number, timestamp}, {durations, last_block_number, last_timestamp} ->
      if last_timestamp do
        block_numbers_range = last_block_number - block_number
        duration = (last_timestamp - timestamp) / block_numbers_range
        {[duration | durations], block_number, timestamp}
      else
        {durations, block_number, timestamp}
      end
    end)
    |> elem(0)
  end
end
