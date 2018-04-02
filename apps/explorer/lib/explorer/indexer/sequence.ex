defmodule Explorer.Indexer.Sequence do
  @moduledoc false

  use Agent

  defstruct ~w(current mode queue step)a

  @type range :: {pos_integer(), pos_integer()}

  @doc """
  Stars a process for managing a block sequence.
  """
  @spec start_link([range()], pos_integer(), pos_integer()) :: Agent.on_start()
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

  @doc """
  Adds a range of block numbers to the sequence.
  """
  @spec inject_range(pid(), range()) :: :ok
  def inject_range(sequencer, {_first, _last} = range) when is_pid(sequencer) do
    Agent.update(sequencer, fn state ->
      %__MODULE__{state | queue: :queue.in(range, state.queue)}
    end)
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
  Pops the next block range from the sequence.
  """
  @spec pop(pid()) :: range() | :halt
  def pop(sequencer) when is_pid(sequencer) do
    Agent.get_and_update(sequencer, fn %__MODULE__{current: current, step: step} = state ->
      case {state.mode, :queue.out(state.queue)} do
        {_, {{:value, {starting, ending}}, new_queue}} ->
          {{starting, ending}, %__MODULE__{state | queue: new_queue}}

        {:infinite, {:empty, new_queue}} ->
          {{current, current + step - 1}, %__MODULE__{state | current: current + step, queue: new_queue}}

        {:finite, {:empty, new_queue}} ->
          {:halt, %__MODULE__{state | queue: new_queue}}
      end
    end)
  end
end
