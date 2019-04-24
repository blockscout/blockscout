defmodule Indexer.Block.Catchup.Sequence do
  @moduledoc false

  use GenServer

  alias Indexer.{BoundQueue, Memory}

  @enforce_keys ~w(current bound_queue step)a
  defstruct current: nil,
            bound_queue: %BoundQueue{},
            step: nil

  @typedoc """
  The ranges to stream from the `t:Stream.t/` returned from `build_stream/1`
  """
  @type ranges :: [Range.t()]

  @typep ranges_option :: {:ranges, ranges}

  @typedoc """
  The first number in the sequence to start for infinite sequences.
  """
  @type first :: integer()

  @typep first_option :: {:first, first}

  @typedoc """
   * `:finite` - only popping ranges from `queue`.
   * `:infinite` - generating new ranges from `current` and `step` when `queue` is empty.
  """
  @type mode :: :finite | :infinite

  @typedoc """
  The size of `t:Range.t/0` to construct based on the `t:first_named_argument/0` or its current value when all
  `t:prefix/0` ranges and any `t:Range.t/0`s injected with `inject_range/2` are consumed.
  """
  @type step :: neg_integer() | pos_integer()

  @typep step_named_argument :: {:step, step}

  @typep memory_monitor_option :: {:memory_monitor, GenServer.server()}

  @type options :: [ranges_option | first_option | memory_monitor_option | step_named_argument]

  @typep edge :: :front | :back

  @typep range_tuple :: {first :: non_neg_integer(), last :: non_neg_integer()}

  @typep t :: %__MODULE__{
           bound_queue: BoundQueue.t(range_tuple()),
           current: nil | integer(),
           step: step()
         }

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  @doc """
  Starts a process for managing a block sequence.

  Infinite sequence

      Indexer.Block.Catchup.Sequence.start_link(first: 100, step: 10)

  Finite sequence

      Indexer.Block.Catchup.Sequence.start_link(ranges: [100..0])

  """
  @spec start_link(options(), Keyword.t()) :: GenServer.on_start()
  def start_link(init_options, gen_server_options \\ []) when is_list(init_options) and is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, init_options, gen_server_options)
  end

  @doc """
  Builds an enumerable stream using a sequencer agent.
  """
  @spec build_stream(GenServer.server()) :: Enumerable.t()
  def build_stream(sequencer) do
    Stream.resource(
      fn -> sequencer end,
      fn seq ->
        case pop_front(seq) do
          :halt -> {:halt, seq}
          range -> {[range], seq}
        end
      end,
      fn seq -> seq end
    )
  end

  @doc """
  Changes the mode for the sequence to finite.
  """
  @spec cap(GenServer.server()) :: mode
  def cap(sequence) do
    GenServer.call(sequence, :cap)
  end

  @doc """
  Adds a range of block numbers to the end of the sequence.
  """
  @spec push_back(GenServer.server(), Range.t()) :: :ok | {:error, String.t()}
  def push_back(sequence, _first.._last = range) do
    GenServer.call(sequence, {:push_back, range})
  end

  @doc """
  Adds a range of block numbers to the front of the sequence.
  """
  @spec push_front(GenServer.server(), Range.t()) :: :ok | {:error, String.t()}
  def push_front(sequence, _first.._last = range) do
    GenServer.call(sequence, {:push_front, range})
  end

  @doc """
  Pops the next block range from the sequence.
  """
  @spec pop_front(GenServer.server()) :: Range.t() | :halt
  def pop_front(sequence) do
    GenServer.call(sequence, :pop_front)
  end

  @impl GenServer
  @spec init(options) :: {:ok, t}
  def init(options) when is_list(options) do
    Process.flag(:trap_exit, true)

    shrinkable(options)

    with {:ok, %{ranges: ranges, first: first, step: step}} <- validate_options(options),
         {:ok, bound_queue} <- push_chunked_ranges(%BoundQueue{}, step, ranges) do
      {:ok, %__MODULE__{bound_queue: bound_queue, current: first, step: step}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer

  @spec handle_call(:cap, GenServer.from(), %__MODULE__{current: nil}) :: {:reply, :finite, %__MODULE__{current: nil}}
  @spec handle_call(:cap, GenServer.from(), %__MODULE__{current: integer()}) ::
          {:reply, :infinite, %__MODULE__{current: nil}}
  def handle_call(:cap, _from, %__MODULE__{current: current} = state) do
    mode =
      case current do
        nil -> :finite
        _ -> :infinite
      end

    {:reply, mode, %__MODULE__{state | current: nil}}
  end

  @spec handle_call({:push_back, Range.t()}, GenServer.from(), t()) :: {:reply, :ok | {:error, String.t()}, t()}
  def handle_call({:push_back, _first.._last = range}, _from, %__MODULE__{bound_queue: bound_queue, step: step} = state) do
    case push_chunked_range(bound_queue, step, range) do
      {:ok, updated_bound_queue} ->
        {:reply, :ok, %__MODULE__{state | bound_queue: updated_bound_queue}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @spec handle_call({:push_front, Range.t()}, GenServer.from(), t()) :: {:reply, :ok | {:error, String.t()}, t()}
  def handle_call(
        {:push_front, _first.._last = range},
        _from,
        %__MODULE__{bound_queue: bound_queue, step: step} = state
      ) do
    case push_chunked_range(bound_queue, step, range, :front) do
      {:ok, updated_bound_queue} ->
        {:reply, :ok, %__MODULE__{state | bound_queue: updated_bound_queue}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @spec handle_call(:pop_front, GenServer.from(), t()) :: {:reply, Range.t() | :halt, t()}
  def handle_call(:pop_front, _from, %__MODULE__{bound_queue: bound_queue, current: current, step: step} = state) do
    {reply, new_state} =
      case {current, BoundQueue.pop_front(bound_queue)} do
        {_, {:ok, {{first, last}, new_bound_queue}}} ->
          {first..last, %__MODULE__{state | bound_queue: new_bound_queue}}

        {nil, {:error, :empty}} ->
          {:halt, %__MODULE__{state | bound_queue: bound_queue}}

        {_, {:error, :empty}} ->
          case current + step do
            new_current ->
              last = new_current - 1
              {current..last, %__MODULE__{state | current: new_current, bound_queue: bound_queue}}
          end
      end

    {:reply, reply, new_state}
  end

  @spec handle_call(:shrink, GenServer.from(), t()) :: {:reply, :ok, t()}
  def handle_call(:shrink, _from, %__MODULE__{bound_queue: bound_queue} = state) do
    {reply, shrunk_state} =
      case BoundQueue.shrink(bound_queue) do
        {:error, :minimum_size} = error ->
          {error, state}

        {:ok, shrunk_bound_queue} ->
          {:ok, %__MODULE__{state | bound_queue: shrunk_bound_queue}}
      end

    {:reply, reply, shrunk_state, :hibernate}
  end

  @spec handle_call(:shrunk?, GenServer.from(), t()) :: {:reply, boolean(), t()}
  def handle_call(:shrunk?, _from, %__MODULE__{bound_queue: bound_queue} = state) do
    {:reply, BoundQueue.shrunk?(bound_queue), state}
  end

  @spec push_chunked_range(BoundQueue.t(Range.t()), step, Range.t(), edge()) ::
          {:ok, BoundQueue.t(Range.t())} | {:error, reason :: String.t()}
  defp push_chunked_range(bound_queue, step, _.._ = range, edge \\ :back)
       when is_integer(step) and edge in [:back, :front] do
    with {:error, [reason]} <- push_chunked_ranges(bound_queue, step, [range], edge) do
      {:error, reason}
    end
  end

  @spec push_chunked_range(BoundQueue.t(Range.t()), step, [Range.t()], edge()) ::
          {:ok, BoundQueue.t(Range.t())} | {:error, reasons :: [String.t()]}
  defp push_chunked_ranges(bound_queue, step, ranges, edge \\ :back)
       when is_integer(step) and is_list(ranges) and edge in [:back, :front] do
    reducer =
      case edge do
        :back -> &BoundQueue.push_back(&2, &1)
        :front -> &BoundQueue.push_front(&2, &1)
      end

    reduce_chunked_ranges(ranges, step, bound_queue, reducer)
  end

  defp reduce_chunked_ranges(ranges, step, initial, reducer)
       when is_list(ranges) and is_integer(step) and step != 0 and is_function(reducer, 2) do
    Enum.reduce(ranges, {:ok, initial}, fn
      range, {:ok, acc} ->
        case reduce_chunked_range(range, step, acc, reducer) do
          {:ok, _} = ok ->
            ok

          {:error, reason} ->
            {:error, [reason]}
        end

      range, {:error, acc_reasons} = acc ->
        case reduce_chunked_range(range, step, initial, reducer) do
          {:ok, _} -> acc
          {:error, reason} -> {:error, [reason | acc_reasons]}
        end
    end)
  end

  defp reduce_chunked_range(_.._ = range, step, initial, reducer) do
    count = Enum.count(range)
    reduce_chunked_range(range, count, step, initial, reducer)
  end

  defp reduce_chunked_range(first..last = range, _count, step, _initial, _reducer)
       when (step < 0 and first < last) or (0 < step and last < first) do
    {:error, "Range (#{inspect(range)}) direction is opposite step (#{step}) direction"}
  end

  defp reduce_chunked_range(first..last, count, step, initial, reducer) when count <= abs(step) do
    reducer.({first, last}, initial)
  end

  defp reduce_chunked_range(first..last, _, step, initial, reducer) do
    {sign, comparator} =
      if step > 0 do
        {1, &Kernel.>=/2}
      else
        {-1, &Kernel.<=/2}
      end

    first
    |> Stream.iterate(&(&1 + step))
    |> Enum.reduce_while(
      initial,
      &reduce_whiler(&1, &2, %{step: step, sign: sign, comparator: comparator, last: last, reducer: reducer})
    )
  end

  defp reduce_whiler(chunk_first, acc, %{step: step, sign: sign, comparator: comparator, last: last, reducer: reducer}) do
    next_chunk_first = chunk_first + step
    full_chunk_last = next_chunk_first - sign

    {action, chunk_last} =
      if comparator.(full_chunk_last, last) do
        {:halt, last}
      else
        {:cont, full_chunk_last}
      end

    case reducer.({chunk_first, chunk_last}, acc) do
      {:ok, reduced} ->
        case action do
          :halt -> {:halt, {:ok, reduced}}
          :cont -> {:cont, reduced}
        end

      {:error, _} = error ->
        {:halt, error}
    end
  end

  defp shrinkable(options) do
    case Keyword.get(options, :memory_monitor) do
      nil -> :ok
      memory_monitor -> Memory.Monitor.shrinkable(memory_monitor)
    end
  end

  defp validate_options(options) do
    step = Keyword.fetch!(options, :step)

    case {Keyword.fetch(options, :ranges), Keyword.fetch(options, :first)} do
      {:error, {:ok, first}} ->
        case step do
          pos_integer when is_integer(pos_integer) and pos_integer > 0 ->
            {:ok, %{ranges: [], first: first, step: step}}

          _ ->
            {:error, ":step must be a positive integer for infinite sequences"}
        end

      {{:ok, ranges}, :error} ->
        {:ok, %{ranges: ranges, first: nil, step: step}}

      {{:ok, _}, {:ok, _}} ->
        {:error,
         ":ranges and :first cannot be set at the same time as :ranges is for :finite mode while :first is for :infinite mode"}

      {:error, :error} ->
        {:error, "either :ranges or :first must be set"}
    end
  end
end
