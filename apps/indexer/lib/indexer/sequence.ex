defmodule Indexer.Sequence do
  @moduledoc false

  use GenServer

  @enforce_keys ~w(current queue step)a
  defstruct current: nil,
            queue: nil,
            step: nil,
            mode: :infinite

  @typedoc """
  The initial ranges to stream from the `t:Stream.t/` returned from `build_stream/1`
  """
  @type prefix :: [Range.t()]

  @typep prefix_option :: {:prefix, prefix}

  @typedoc """
  The first number in the sequence to start at once the `t:prefix/0` ranges and any `t:Range.t/0`s injected with
  `inject_range/2` are all consumed.
  """
  @type first :: pos_integer()

  @typep first_named_argument :: {:first, pos_integer()}

  @type mode :: :infinite | :finite

  @typedoc """
  The size of `t:Range.t/0` to construct based on the `t:first_named_argument/0` or its current value when all
  `t:prefix/0` ranges and any `t:Range.t/0`s injected with `inject_range/2` are consumed.
  """
  @type step :: neg_integer() | pos_integer()

  @typep step_named_argument :: {:step, step}

  @type options :: [prefix_option | first_named_argument | step_named_argument]

  @typep t :: %__MODULE__{
           current: pos_integer(),
           queue: :queue.queue(Range.t()),
           step: step(),
           mode: mode()
         }

  @doc """
  Starts a process for managing a block sequence.
  """
  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options)
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
  Changes the mode for the sequencer to signal continuous streaming mode.

  Returns the previous `t:mode/0`.
  """
  @spec cap(pid()) :: mode
  def cap(sequence) when is_pid(sequence) do
    GenServer.call(sequence, :cap)
  end

  @doc """
  Adds a range of block numbers to the sequence.
  """
  @spec inject_range(pid(), Range.t()) :: :ok
  def inject_range(sequence, _first.._last = range) when is_pid(sequence) do
    GenServer.call(sequence, {:inject_range, range})
  end

  @doc """
  Pops the next block range from the sequence.
  """
  @spec pop(pid()) :: Range.t() | :halt
  def pop(sequence) when is_pid(sequence) do
    GenServer.call(sequence, :pop)
  end

  @impl GenServer
  @spec init(options) :: {:ok, t}
  def init(named_arguments) when is_list(named_arguments) do
    Process.flag(:trap_exit, true)

    {:ok,
     %__MODULE__{
       queue:
         named_arguments
         |> Keyword.get(:prefix, [])
         |> :queue.from_list(),
       current: Keyword.fetch!(named_arguments, :first),
       step: Keyword.fetch!(named_arguments, :step)
     }}
  end

  @impl GenServer

  @spec handle_call(:cap, GenServer.from(), t()) :: {:reply, mode(), %__MODULE__{mode: :infinite}}
  def handle_call(:cap, _from, %__MODULE__{mode: mode} = state) do
    {:reply, mode, %__MODULE__{state | mode: :finite}}
  end

  @spec handle_call({:inject_range, Range.t()}, GenServer.from(), t()) :: {:reply, mode(), t()}
  def handle_call({:inject_range, _first.._last = range}, _from, %__MODULE__{queue: queue} = state) do
    {:reply, :ok, %__MODULE__{state | queue: :queue.in(range, queue)}}
  end

  @spec handle_call(:pop, GenServer.from(), t()) :: {:reply, Range.t() | :halt, t()}
  def handle_call(:pop, _from, %__MODULE__{mode: mode, queue: queue, current: current, step: step} = state) do
    {reply, new_state} =
      case {mode, :queue.out(queue)} do
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

    {:reply, reply, new_state}
  end

  @spec sign(neg_integer()) :: -1
  defp sign(integer) when integer < 0, do: -1

  @spec sign(non_neg_integer()) :: 1
  defp sign(_), do: 1
end
