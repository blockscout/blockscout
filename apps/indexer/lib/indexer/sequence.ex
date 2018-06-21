defmodule Indexer.Sequence do
  @moduledoc false

  use Agent

  defstruct ~w(current mode queue step)a

  @doc """
  Builds an enumerable stream using a sequencer agent.
  """
  @spec build_stream(pid()) :: Enumerable.t()
  def build_stream(sequencer) when is_pid(sequencer) do
    Stream.resource(
      fn -> sequencer end,
      fn seq ->
        case pop(seq) do
          :halt -> {:halt, seq}
          range -> {[range], seq}
        end
      end,
      fn seq -> seq end
    )
  end

  @doc """
  Changes the mode for the sequencer to signal continuous streaming mode.
  """
  @spec cap(pid()) :: :ok
  def cap(sequencer) when is_pid(sequencer) do
    Agent.update(sequencer, fn state ->
      %__MODULE__{state | mode: :finite}
    end)
  end

  @doc """
  Adds a range of block numbers to the sequence.
  """
  @spec inject_range(pid(), Range.t()) :: :ok
  def inject_range(sequencer, _first.._last = range) when is_pid(sequencer) do
    Agent.update(sequencer, fn state ->
      %__MODULE__{state | queue: :queue.in(range, state.queue)}
    end)
  end

  @doc """
  Pops the next block range from the sequence.
  """
  @spec pop(pid()) :: Range.t() | :halt
  def pop(sequencer) when is_pid(sequencer) do
    Agent.get_and_update(sequencer, &pop_state/1)
  end

  @doc """
  Stars a process for managing a block sequence.
  """
  @spec start_link([Range.t()], pos_integer(), neg_integer() | pos_integer()) :: Agent.on_start()
  def start_link(initial_ranges, range_start, step) do
    Agent.start_link(fn ->
      %__MODULE__{
        current: range_start,
        step: step,
        mode: :infinite,
        queue: :queue.from_list(initial_ranges)
      }
    end)
  end

  defp pop_state(%__MODULE__{current: current, step: step} = state) do
    case {state.mode, :queue.out(state.queue)} do
      {_, {{:value, range}, new_queue}} ->
        {range, %__MODULE__{state | queue: new_queue}}

      {:infinite, {:empty, new_queue}} ->
        case current + step do
          negative when negative < 0 ->
            {current..0, %__MODULE__{state | current: 0, mode: :finite, queue: new_queue}}

          new_current ->
            last = new_current - sign(step)
            {current..last, %__MODULE__{state | current: new_current, queue: new_queue}}
        end

      {:finite, {:empty, new_queue}} ->
        {:halt, %__MODULE__{state | queue: new_queue}}
    end
  end

  defp sign(integer) when integer < 0, do: -1
  defp sign(_), do: 1
end
