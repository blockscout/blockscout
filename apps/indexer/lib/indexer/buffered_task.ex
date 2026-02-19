defmodule Indexer.BufferedTask do
  @moduledoc """
  Provides a behaviour for batched task running with retries and memory-aware buffering.

  This module implements a generic buffered task system that allows for efficient
  processing of data in batches. It manages a queue of entries, processes them
  concurrently up to a specified limit, and provides mechanisms for retrying
  failed tasks. The module is designed to be memory-aware, with the ability to
  shrink its memory usage when requested by a memory monitor.

  The `BufferedTask` operates as follows:

  1. Initialization:
    When a module implementing the `BufferedTask` behaviour is started as part of
    a supervision tree, it must use `BufferedTask.child_spec/1` to define its
    child specification. This ensures that `BufferedTask.start_link/2` is called
    correctly, initializing the `BufferedTask` process with the implementing
    module's options. During this initialization, the periodic flushing of
    buffers to the processing queue is also set up, establishing an automated
    cycle of data processing.

  2. Initial Data Streaming:
    Upon initialization, the `BufferedTask` sends itself an `:initial_stream`
    message. This triggers a call to the `init/3` callback of the implementing
    module, populating the queue with initial data.

  3. Data Processing Flow:
    a. Data Entry:
        - External processes can add entries to the buffer using the `buffer/4`
          function. This function allows for both synchronous and asynchronous
          buffering of entries, with an option to prioritize entries.
    b. Flushing:
        - Periodically, based on the `flush_interval`, or when manually triggered,
          the buffered entries are moved to the main processing queue. This
          flushing process automatically triggers the processing of the next
          batch of queue data, ensuring continuous data handling without manual
          intervention.
    c. Batch Processing:
        - As concurrency becomes available (controlled by `max_concurrency`),
          batches of entries (size determined by `max_batch_size`) are taken from
          the queue and processed by spawning tasks that call the `run/2` callback
          of the implementing module.
    d. Retry Mechanism:
        - If a task fails or explicitly requests a retry, the entries are
          re-added to the queue for another processing attempt.

  The entire process of periodic flushing, batch processing, and retry handling
  is automated, requiring no manual management once the `BufferedTask` is
  initialized. This design ensures efficient and continuous data processing with
  minimal overhead.

  The `BufferedTask` is designed to be memory-aware and can interact with a
  memory monitor to adjust its memory usage when system resources are constrained.
  It also provides debugging capabilities to monitor its internal state and
  performance.

  ## Initialization Parameters

  The following parameters are passed to `BufferedTask.init/1` through
  `BufferedTask.child_spec/1` and `BufferedTask.start_link/2`:

  - `:callback_module`: Required. The module implementing the `BufferedTask`
    behaviour.
  - `:task_supervisor`: Required. The name of the `Task.Supervisor` to spawn
    tasks under.
  - `:flush_interval`: Required. The interval in milliseconds between automatic
    queue flushes. Set to `:infinity` to disable automatic flushing.
  - `:max_batch_size`: Required. The maximum number of entries to be processed
    in a single batch.
  - `:max_concurrency`: Required. The maximum number of concurrent processing
    tasks allowed.
  - `:memory_monitor`: Optional. The `Indexer.Memory.Monitor` server to register
    with for memory-aware operations.
  - `:poll`: Optional. Boolean flag to enable/disable polling for new data after
    processing all current entries. Defaults to `true`.
  - `:state`: Required. Initial state for the callback module. This can include
    any parameters or initial values required for proper functioning of `init`
    and `run` callbacks.
  - `:metadata`: Optional. Logger metadata to set in the `BufferedTask` process
    and its child processes.

  ## Callbacks

  ### `c:init/3`

  @callback init(initial, reducer, state) :: {final, state}

  This callback is invoked during the initial streaming process to populate the
  queue with initial data. It runs in a separate task, allowing for long-running
  operations without blocking the main `BufferedTask` process.

  - `initial`: An opaque value representing the initial accumulator. Its structure
    and content are fully controlled by the `reducer` function, so there's no need
    to handle this parameter specifically within the `init/3` callback.
  - `reducer`: A function that accumulates entries into the `BufferedTask`'s
    internal buffers.
  - `state`: The initial state provided during initialization.

  The `init/3` callback should use the `reducer` function to add entries to the
  `BufferedTask`'s buffers. The `BufferedTask` will automatically manage these
  entries, flushing them to the main processing queue and initiating batch
  processing as needed.

  ### `c:run/2`

  @callback run(entries, state) :: :ok | {:ok, state} | :retry | {:retry, new_entries :: list} | {:retry, new_entries :: list, state}

  This callback is invoked as concurrency becomes available to process batches
  of entries from the queue. It is called within a task spawned by the
  `Task.Supervisor` specified during initialization.

  - `entries`: A list of entries to be processed, with a maximum length of
    `:max_batch_size`.
  - `state`: The current state of the callback module.

  The `run/2` callback processes the given entries and returns one of the following
  possible results:

  - `:ok`: Indicates successful processing.
  - `{:ok, state}`: Indicates successful processing and requests an update to
    the callback module state.
  - `:retry`: Signals that the entire batch should be retried.
  - `{:retry, new_entries}`: Specifies a new list of entries to be retried. This
    can be a completely new list of entries or a subset of entries which were not
    successfully handled by `run/2` in this iteration.
  - `{:retry, new_entries, state}`: Specifies a new list of entries to be retried
    and requests an update to the callback module state.

  If the callback crashes, the `BufferedTask` will automatically retry the batch.
  The retry mechanism ensures resilience in data processing, allowing for
  temporary failures or resource unavailability to be handled gracefully.

  The `BufferedTask` manages concurrency, ensuring that no more than
  `:max_concurrency` `run/2` callbacks are executing simultaneously. This
  provides controlled parallelism while preventing system overload.

  ## Examples

  ### Typical Usage

  Here's a comprehensive example of a module implementing the BufferedTask behaviour
  for processing random integers:

      defmodule NumberProcessor do
        # Will generate the Supervisor and TaskSupervisor for NumberProcessor
        use Indexer.Fetcher, restart: :permanent

        alias Indexer.BufferedTask

        def child_spec([init_options, gen_server_options]) do
          state = %{initial_count: 50}

          buffered_task_init_options =
            [
              poll: false,
              flush_interval: 5000,
              max_batch_size: 10,
              max_concurrency: 2,
              task_supervisor: NumberProcessor.TaskSupervisor,
              metadata: [task: :number_processor]
            ]
            |> Keyword.merge(init_options)
            |> Keyword.put(:state, state)

          Supervisor.child_spec(
            {BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
            id: __MODULE__
          )
        end

        @impl BufferedTask
        def init(initial, reducer, %{initial_count: count}) do
          Enum.reduce(1..count, initial, fn _, acc ->
            number = :rand.uniform(1000)
            reducer.(number, acc)
          end)
        end

        @impl BufferedTask
        def run(numbers, _state) do
          Enum.each(numbers, fn number ->
            result = if rem(number, 2) == 0, do: "even", else: "odd"
            IO.puts("Number \#{number} is \#{result}")
          end)
          :ok
        end

        def add_numbers(count, high_priority?) do
          numbers = Enum.map(1..count, fn _ -> :rand.uniform(1000) end)
          BufferedTask.buffer(__MODULE__, numbers, high_priority?)
        end
      end

  To use this module in your application's supervision tree:

      children = [
        {NumberProcessor.Supervisor, [[memory_monitor: memory_monitor]]}
      ]

      Supervisor.init(children, strategy: :one_for_one)

  This setup assumes you have a memory_monitor defined elsewhere in your application.

  To add more numbers to the buffer after initialization:

      NumberProcessor.add_numbers(20, false)  # Add 20 numbers with normal priority
      NumberProcessor.add_numbers(5, true)    # Add 5 numbers with high priority

  ### Minimal Init and Retry Example

  This example demonstrates two key features of BufferedTask: a minimal `init/3`
  callback that simply passes through the initial state and use of `{:retry, new_entries}`
  in the `run/2` callback for task rescheduling.

      defmodule TaskScheduler do
        use Indexer.Fetcher, restart: :permanent

        alias Indexer.BufferedTask

        def child_spec([init_options, gen_server_options]) do
          state = %{max_retries: 3}

          buffered_task_init_options =
            [
              poll: false,
              flush_interval: 1000,
              max_batch_size: 10,
              max_concurrency: 5,
              task_supervisor: TaskScheduler.TaskSupervisor,
              metadata: [fetcher: :task_scheduler]
            ]
            |> Keyword.merge(init_options)
            |> Keyword.put(:state, state)

          Supervisor.child_spec(
            {BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
            id: __MODULE__
          )
        end

        @impl BufferedTask
        def init(initial, _reducer, _state) do
          initial
        end

        @impl BufferedTask
        def run(tasks, %{max_retries: max_retries} = state) do
          now = System.system_time(:millisecond)
          {due_tasks, future_tasks} = Enum.split_with(tasks, &(&1.at <= now))

          new_future_tasks = Enum.map(due_tasks, fn task ->
            case execute_task(task) do
              :ok -> nil
              :error ->
                retry_count = Map.get(task, :retry_count, 0)
                if retry_count < max_retries do
                  %{task | retry_count: retry_count + 1}
                end
            end
          end)
          |> Enum.reject(&is_nil/1)

          case future_tasks ++ new_future_tasks do
            [] -> :ok
            remaining_tasks -> {:retry, remaining_tasks}
          end
        end

        defp execute_task(%{fun: fun, args: args}) do
          try do
            apply(fun, args)
            :ok
          rescue
            _ -> :error
          end
        end

        def schedule_task(at, fun, args) do
          task = %{at: at, fun: fun, args: args}
          BufferedTask.buffer(__MODULE__, [task], false)
        end
      end

  To use this module in your application's supervision tree:

      children = [
        {TaskScheduler.Supervisor, [[memory_monitor: memory_monitor]]}
      ]

      Supervisor.init(children, strategy: :one_for_one)

  To schedule a new task:

      TaskScheduler.schedule_task(
        System.system_time(:millisecond) + 5000,
        fn -> IO.puts("Hello from the future!") end,
        []
      )
  """

  use GenServer

  require Logger

  import Indexer.Logger, only: [process: 1]

  alias Explorer.BoundQueue
  alias Indexer.Memory

  @enforce_keys [
    :callback_module,
    :callback_module_state,
    :task_supervisor,
    :flush_interval,
    :max_batch_size
  ]
  defstruct init_task: nil,
            init_task_delay: 0,
            flush_timer: nil,
            callback_module: nil,
            callback_module_state: nil,
            task_supervisor: nil,
            flush_interval: nil,
            max_batch_size: nil,
            max_concurrency: nil,
            poll: true,
            metadata: [],
            current_buffer: [],
            current_front_buffer: [],
            bound_queue: %BoundQueue{},
            task_ref_to_batch: %{}

  @typedoc """
  BufferedTask struct:
  * `init_task` - reference to the initial streaming task. This field holds the
    `reference()` for the initial data population process. It's used to track the
    completion of the initial data streaming.
  * `init_task_delay` - delay between running init tasks.
    It increases if the last init task added nothing to queue and resets to 0 otherwise.
  * `flush_timer` - reference to the timer for periodic buffer flushing. This
    field stores the timer reference returned by `Process.send_after/3`, which
    is scheduled using the `flush_interval`. When the timer triggers, it sends
    a `:flush` message to the process, initiating a buffer flush operation.
    This field is managed internally and doesn't need to be set by the user.
  * `callback_module` - module implementing the `BufferedTask` behaviour. This
    field must be set when initializing the `BufferedTask`. It specifies the
    module that defines the `init/3` and `run/2` callbacks, which are crucial
    for the operation of the buffered task.
  * `callback_module_state` - state maintained by the callback module. This
    field holds any state that the callback module needs to persist between
    calls to its callbacks. It's passed to and potentially updated by the
    `run/2` callback.
  * `task_supervisor` - name of the `Task.Supervisor` for spawning tasks. This
    field must be set during initialization. It's used to spawn concurrent
    tasks for processing batches of data, allowing for controlled
    concurrency.
  * `flush_interval` - interval in milliseconds between buffer flushes. This
    field must be set during initialization. It determines how often the
    buffer is automatically flushed, ensuring that data is processed even
    if the buffer doesn't fill up quickly. If set to `:infinity`, no automatic
    flushing occurs - it can be used for when manual flushing is preferred by
    sending a `:flush` message to the process.
  * `max_batch_size` - maximum number of entries in a batch for processing.
    This field must be set during initialization. It controls the size of
    batches sent to the `run/2` callback, allowing for optimized processing
    of data.
  * `max_concurrency` - maximum number of concurrent processing tasks. This
    field must be set during initialization. It limits the number of
    simultaneous `run/2` callback executions, preventing system overload.
  * `poll` - boolean flag to enable/disable polling for new records. This field
    has a default value of true. When true, the module will continue to call
    `init/3` to fetch new data after processing all current entries.
  * `metadata` - list of metadata for logging purposes. This field can be set
    during initialization. It's used to add context to log messages,
    improving the traceability of the buffered task's operations.
  * `current_buffer` - list of entries waiting to be processed. This field is
    used internally to store incoming entries before they're moved to the
    bound_queue for processing. Acts as a temporary holding area for
    incoming data.
  * `current_front_buffer` - list of high-priority entries for processing. These
    entries are moved to the front of the bound_queue during flushing.
  * `bound_queue` - queue with a maximum size limit for storing entries. This
    field uses a `BoundQueue` struct to efficiently manage entries while
    respecting memory constraints.
  * `task_ref_to_batch` - map of task references to their corresponding batches.
    This field is used internally to keep track of which batch is being
    processed by each spawned task, facilitating proper handling of task
    results and retries.
  """
  @type t :: %__MODULE__{
          init_task: reference() | :complete | :delay | nil,
          init_task_delay: non_neg_integer(),
          flush_timer: reference() | nil,
          callback_module: module(),
          callback_module_state: term(),
          task_supervisor: GenServer.name(),
          flush_interval: timeout() | :infinity,
          max_batch_size: non_neg_integer(),
          max_concurrency: non_neg_integer(),
          poll: boolean(),
          metadata: Logger.metadata(),
          current_buffer: [term(), ...],
          current_front_buffer: [term(), ...],
          bound_queue: BoundQueue.t(term()),
          task_ref_to_batch: %{reference() => [term(), ...]}
        }

  @typedoc """
  Entry passed to `t:reducer/2` in `c:init/2` and grouped together into a list as `t:entries/0` passed to `c:run/2`.
  """
  @type entry :: term()

  @typedoc """
  List of `t:entry/0` passed to `c:run/2`.
  """
  @type entries :: [entry, ...]

  @typedoc """
  The initial `t:accumulator/0` for `c:init/2`.
  """
  @opaque initial :: {0, []}

  @typedoc """
  The accumulator passed through the `t:reducer/0` for `c:init/2`.
  """
  @opaque accumulator :: {non_neg_integer(), list()}

  @typedoc """
  Reducer for `c:init/2`.

  Accepts entry generated by callback module and passes through `accumulator`.  `Explorer.BufferTask` itself will decide
  how to integrate `entry` into `accumulator` or to run `c:run/2`.
  """
  @type reducer :: (entry, accumulator -> accumulator)

  @typedoc """
  Callback module controlled state.  Can be used to store extra information needed for each `run/2`
  """
  @type state :: term()

  @doc """
    This callback is invoked during the initial streaming process to populate the
    queue with initial data. It runs in a separate task, allowing for long-running
    operations without blocking the main `BufferedTask` process.

    - `initial`: An opaque value representing the initial accumulator. Its structure
      and content are fully controlled by the `reducer` function, so there's no need
      to handle this parameter specifically within the `init/3` callback.
    - `reducer`: A function that accumulates entries into the `BufferedTask`'s
      internal buffers.
    - `state`: The initial state provided during initialization.

    The `init/3` callback should use the `reducer` function to add entries to the
    `BufferedTask`'s buffers. The `BufferedTask` will automatically manage these
    entries, flushing them to the main processing queue and initiating batch
    processing as needed.
  """
  @callback init(initial, reducer, state) :: accumulator

  @doc """
    This callback is invoked as concurrency becomes available to process batches
    of entries from the queue. It is called within a task spawned by the
    `Task.Supervisor` specified during initialization.

    - `entries`: A list of entries to be processed, with a maximum length of
      `:max_batch_size`.
    - `state`: The current state of the callback module.

    The `run/2` callback processes the given entries and returns one of the following
    possible results:

    - `:ok`: Indicates successful processing.
    - `{:ok, state}`: Indicates successful processing and requests an update to
      the callback module state.
    - `:retry`: Signals that the entire batch should be retried.
    - `{:retry, new_entries}`: Specifies a new list of entries to be retried. This
      can be a completely new list of entries or a subset of entries which were not
      successfully handled by `run/2` in this iteration.
    - `{:retry, new_entries, state}`: Specifies a new list of entries to be retried
      and requests an update to the callback module state.

    If the callback crashes, the `BufferedTask` will automatically retry the batch.
    The retry mechanism ensures resilience in data processing, allowing for
    temporary failures or resource unavailability to be handled gracefully.

    The `BufferedTask` manages concurrency, ensuring that no more than
    `:max_concurrency` `run/2` callbacks are executing simultaneously. This
    provides controlled parallelism while preventing system overload.
  """
  @callback run(entries, state) ::
              :ok | {:ok, state} | :retry | {:retry, new_entries :: list} | {:retry, new_entries :: list, state}

  @doc """
    Buffers a list of entries for future execution.

    This function sends a message to the specified BufferedTask process to add the
    given entries to one of two internal buffers:
    1. The regular buffer, if `front?` is `false`.
    2. The front buffer, if `front?` is `true`.

    When the buffers are later flushed asynchronously:
    - Entries from the regular buffer are added to the end of the processing queue.
    - Entries from the front buffer are added to the beginning of the processing queue.

    Note: If the total number of elements in the buffers exceeds the maximum queue
    size (which is undefined by default) when flushed, excess elements will be
    dropped without notification to the calling process.

    ## Parameters
    - `server`: The name or PID of the BufferedTask process.
    - `entries`: A list of entries to be buffered.
    - `front?`: If `true`, entries are added to the front buffer; if `false`,
      they are added to the regular buffer.
    - `timeout`: The maximum time to wait for a reply, in milliseconds. Defaults to
      5000 ms.

    ## Returns
    - `:ok` if the entries were successfully added to the appropriate buffer.
  """
  @spec buffer(GenServer.name(), entries(), boolean()) :: :ok
  @spec buffer(GenServer.name(), entries(), boolean(), timeout()) :: :ok
  def buffer(server, entries, front?, timeout \\ 5000) when is_list(entries) do
    GenServer.call(server, {:buffer, entries, front?}, timeout)
  end

  @doc """
    Defines a child specification for a BufferedTask to be used in a supervision tree.

    ## Parameters
    - `[init_arguments]` or `[init_arguments, gen_server_options]`:
      - `init_arguments`: A list of initialization arguments for the BufferedTask.
      - `gen_server_options`: An optional list of GenServer options.

    ## Returns
    A child specification map suitable for use in a supervision tree.

    ## Usage
    This function is typically called indirectly as part of the `child_spec/1`
    function of a module implementing the BufferedTask behavior. It's not intended
    to be called directly in application code.
  """
  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  @doc """
    Retrieves debug information about the current state of the BufferedTask.

    Returns a map containing the total number of entries in buffers and queue,
    and the number of active tasks. This function is useful for monitoring and
    debugging the BufferedTask's internal state.

    ## Parameters
    - `server`: The name or PID of the BufferedTask process.
    - `current_front_buffer?`: If `true`, includes entries in the front buffer
      in the total count; if `false`, only includes entries in the regular buffer
      and the processing queue.

    ## Returns
    A map with keys `:buffer` (total entries count) and `:tasks` (active tasks count).
  """
  @spec debug_count(GenServer.name(), boolean()) :: %{buffer: non_neg_integer(), tasks: non_neg_integer()}
  def debug_count(server, current_front_buffer? \\ true) do
    GenServer.call(server, {:debug_count, current_front_buffer?})
  end

  @doc """
    Starts a `BufferedTask` process for the given callback module.

    This function is generally not called directly in application code. Instead,
    it's used in the context of a supervision tree, typically invoked through
    the `child_spec/1` function of a module implementing the BufferedTask behavior.
    It initializes a BufferedTask process and ultimately leads to calling
    `BufferedTask.init/1`.

    ## Parameters
    The function takes a tuple with two elements:
    1. `callback_module`: The module implementing the `BufferedTask` behavior.
    2. A keyword list of options, which is a merge of application-wide defaults
      and task-specific options.

    ### Named Arguments
    These are required and should be included in the options list:

    * `:flush_interval` - The interval in milliseconds to flush the buffer.
    * `:max_concurrency` - The maximum number of tasks to run concurrently.
    * `:max_batch_size` - The maximum batch size passed to `c:run/2`.
    * `:task_supervisor` - The `Task.Supervisor` name to spawn tasks under.
    * `:state` - Initial state for the callback module.

    ### Options
    These are optional and can be included in the options list:

    * `:name` - The registered name for the new process.
    * `:metadata` - `Logger.metadata/1` to set in the `BufferedTask` process
      and any child processes.
    * `:memory_monitor` - The memory monitor process name, if applicable.

    ## Returns
    * `{:ok, pid()}` if the process starts successfully.
    * `{:error, {:already_started, pid()}}` if the process is already started.

    ## Note
    The options passed to this function are a merge of application-wide defaults
    (retrieved from `Application.get_all_env(:indexer)`) and the task-specific
    options provided when setting up the fetcher.
  """
  @spec start_link(
          {callback_module :: module,
           [
             {:flush_interval, timeout()}
             | {:max_batch_size, pos_integer()}
             | {:max_concurrency, pos_integer()}
             | {:memory_monitor, GenServer.name()}
             | {:name, GenServer.name()}
             | {:task_supervisor, GenServer.name()}
             | {:state, state}
           ]}
        ) :: {:ok, pid()} | {:error, {:already_started, pid()}}
  def start_link({module, base_init_opts}, genserver_opts \\ []) do
    default_opts = Application.get_all_env(:indexer)
    init_opts = Keyword.merge(default_opts, base_init_opts)
    GenServer.start_link(__MODULE__, {module, init_opts}, genserver_opts)
  end

  @doc """
    Initializes the BufferedTask process.

    This function accepts parameters passed from `start_link/2`, sends an
    `:initial_stream` message to self to start the initial streaming process,
    sets up the process as shrinkable if a memory monitor is provided, sets
    Logger metadata, and configures the initial state of `BufferedTask`
    including the state of a module implementing the BufferedTask behavior.

    ## Parameters
    - `{callback_module, opts}`: A tuple containing:
      - `callback_module`: The module implementing the BufferedTask behavior.
      - `opts`: A keyword list of options for initializing the BufferedTask.

    ## Options
    - `:state`: Required. The initial state for the callback module.
    - `:task_supervisor`: Required. The name of the Task.Supervisor.
    - `:flush_interval`: Required. The interval for flushing the buffer to the
      processing queue.
    - `:max_batch_size`: Required. The maximum size of the queue's data batch
      to be processed at once.
    - `:max_concurrency`: Required. The maximum number of concurrent tasks to
      process the queue's data.
    - `:poll`: Optional. Whether to poll for new data from the stream after
      processing all current data. Defaults to `true`.
    - `:metadata`: Optional. Logger metadata. Defaults to an empty list.

    ## Returns
    `{:ok, state}` where `state` is the initialized BufferedTask struct.
  """
  def init({callback_module, opts}) do
    send(self(), :initial_stream)

    # Allows the memory monitor to shrink the amount of elements in the queue
    # when extensive memory usage is detected.
    shrinkable(opts)

    metadata = Keyword.get(opts, :metadata, [])
    Logger.metadata(metadata)

    state = %__MODULE__{
      callback_module: callback_module,
      callback_module_state: Keyword.fetch!(opts, :state),
      poll: Keyword.get(opts, :poll, true),
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      flush_interval: Keyword.fetch!(opts, :flush_interval),
      max_batch_size: Keyword.fetch!(opts, :max_batch_size),
      max_concurrency: Keyword.fetch!(opts, :max_concurrency),
      metadata: metadata
    }

    {:ok, state}
  end

  # Initiates the initial data streaming process in response to the :initial_stream
  # message. This message is self-sent during initialization to start populating
  # the queue with initial data using the `init/3` function of the callback module.
  def handle_info(:initial_stream, state) do
    {:noreply, do_initial_stream(state)}
  end

  # Handles the periodic flush message to process buffered entries.
  # This message is scheduled by the flush_interval to ensure regular processing of
  # accumulated data, pushing it to the queue and triggering batch processing.
  def handle_info(:flush, state) do
    {:noreply, flush(state)}
  end

  # Handles graceful shutdown. A fetcher implementing BufferedTask behaviour
  # can invoke `Process.send(__MODULE__, :shutdown, [])` to shutdown itself.
  # Its `restart` configuration must be set to `:transient`.
  def handle_info(:shutdown, state) do
    {:stop, :shutdown, state}
  end

  # Handles the successful completion of the initial streaming task.
  def handle_info({ref, :ok}, %__MODULE__{init_task: ref} = state) do
    {:noreply, state}
  end

  # Handles the successful completion of a task processing queue data, removes the
  # reference to the task, and triggers processing of the next batch if queue
  # contains data.
  def handle_info({ref, :ok}, state) do
    {:noreply, drop_task(state, ref)}
  end

  # Handles the successful completion of a task processing queue data, updated the
  # callback module state, removes the reference to the task, and triggers processing
  # of the next batch if queue contains data.
  def handle_info({ref, {:ok, new_callback_module_state}}, %__MODULE__{} = state) do
    {:noreply, drop_task(%__MODULE__{state | callback_module_state: new_callback_module_state}, ref)}
  end

  # Handles a retry request for a task processing queue data. The original batch
  # is added back to the queue and processing of the next batch is triggered.
  # Useful when all data from the batch needs to be reprocessed.
  def handle_info({ref, :retry}, state) do
    Logger.debug("Retrying batch with ref #{inspect(ref)}")
    {:noreply, drop_task_and_retry(state, ref)}
  end

  # Handles a retry request for a task processing queue data with specified
  # retryable entries. These entries are added to the queue and processing of
  # the next batch is triggered. Useful when only part of the original batch
  # needs to be reprocessed.
  def handle_info({ref, {:retry, retryable_entries}}, state) do
    Logger.debug("Retrying batch with ref #{inspect(ref)} and specific entries #{inspect(retryable_entries)}")
    {:noreply, drop_task_and_retry(state, ref, retryable_entries)}
  end

  # Handles a retry request for a task processing queue data with specified
  # retryable entries. If the task modified the state, the call back module
  # state is updated. These entries are added to the queue and processing of
  # the next batch is triggered.
  # If all entries are needed to be retried, the `retryable_entries` should
  # be `nil`.
  def handle_info({ref, {:retry, retryable_entries, new_callback_module_state}}, %__MODULE__{} = state) do
    Logger.debug("Retrying batch with ref #{inspect(ref)} and specific entries #{inspect(retryable_entries)}")

    {:noreply,
     drop_task_and_retry(%__MODULE__{state | callback_module_state: new_callback_module_state}, ref, retryable_entries)}
  end

  # Handles the normal termination of the initial streaming task, marking it as complete.
  def handle_info(
        {:DOWN, ref, :process, _pid, :normal},
        %__MODULE__{init_task: ref, bound_queue: %{size: size}} = state
      ) do
    init_task_delay =
      case size do
        0 -> increased_delay()
        _ -> 0
      end

    {:noreply, %__MODULE__{state | init_task: :complete, init_task_delay: init_task_delay}}
  end

  # Handles the normal termination of a non-initial task, no action needed.
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  # Handles abnormal termination of a task processing queue data. The task's batch
  # is re-added to the queue and processing of the next batch is triggered.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    Logger.debug("Task crashed, retrying batch with ref #{inspect(ref)}")
    {:noreply, drop_task_and_retry(state, ref)}
  end

  # Handles asynchronous buffering of entries.
  # Adds the provided entries to either the front or back buffer without waiting for a response.
  # This is used for non-blocking buffering operations.
  def handle_info({:buffer, entries, front?}, state) do
    {:noreply, buffer_entries(state, entries, front?)}
  end

  # Handles synchronous buffering of entries.
  # Adds the provided entries to either the front or back buffer and waits for the operation to complete.
  # This is used when the caller needs confirmation that the entries have been buffered.
  def handle_call({:buffer, entries, front?}, _from, state) do
    {:reply, :ok, buffer_entries(state, entries, front?)}
  end

  # Provides debug information about the current state of the BufferedTask.
  # Returns a count of entries in buffers and queue, and the number of active tasks.
  # This is useful for monitoring and debugging the BufferedTask's internal state.
  def handle_call(
        {:debug_count, current_front_buffer?},
        _from,
        %__MODULE__{
          current_buffer: current_buffer,
          current_front_buffer: current_front_buffer,
          bound_queue: bound_queue,
          max_batch_size: max_batch_size,
          task_ref_to_batch: task_ref_to_batch
        } = state
      ) do
    current_front_buffer_count =
      if current_front_buffer? do
        length(current_front_buffer)
      else
        0
      end

    count = length(current_buffer) + current_front_buffer_count + Enum.count(bound_queue) * max_batch_size

    {:reply, %{buffer: count, tasks: Enum.count(task_ref_to_batch)}, state}
  end

  # Retrieves the full internal state of the BufferedTask.
  # This handler provides complete access to the BufferedTask's state,
  # primarily for advanced debugging, testing, or custom runtime introspection.
  # Use with caution as it exposes internal implementation details.
  def handle_call(
        :state,
        _from,
        state
      ) do
    {:reply, state, state}
  end

  # Adds entries to the back of the queue and initiates processing of the next
  # batch of queue's data by the callback module.
  def handle_call({:push_back, entries}, _from, state) when is_list(entries) do
    new_state =
      state
      |> push_back(entries)
      |> spawn_next_batch()

    {:reply, :ok, new_state}
  end

  # Adds entries to the front of the queue and initiates processing of the next
  # batch of queue's data by the callback module.
  def handle_call({:push_front, entries}, _from, state) when is_list(entries) do
    new_state =
      state
      |> push_front(entries)
      |> spawn_next_batch()

    {:reply, :ok, new_state}
  end

  # Attempts to shrink the bound queue in response to high memory usage detection.
  # Called by the Memory Monitor when this process is identified as a high memory consumer.
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

  # Checks if the bound queue has been previously shrunk.
  # Used by the Memory Monitor to track which processes have been shrunk and may be eligible for expansion.
  def handle_call(:shrunk?, _from, %__MODULE__{bound_queue: bound_queue} = state) do
    {:reply, BoundQueue.shrunk?(bound_queue), state}
  end

  # Expands the previously shrunk bound queue to its original size.
  # Called by the Memory Monitor when overall system memory usage has decreased sufficiently.
  def handle_call(:expand, _from, %__MODULE__{bound_queue: bound_queue} = state) do
    {:reply, :ok, %__MODULE__{state | bound_queue: BoundQueue.expand(bound_queue)}}
  end

  # Removes a task from the state and initiates the next batch processing.
  #
  # This function is called to remove a task reference from the state, regardless
  # of whether the task completed successfully, failed, or needs to be retried.
  # After removing the task, it attempts to spawn the next batch of queue's data
  # for processing.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  # - `ref`: The reference of the task to be removed.
  #
  # ## Returns
  # Updated state after removing the task and potentially spawning a new data
  # portion for processing.
  @spec drop_task(t(), reference()) :: t()
  defp drop_task(%__MODULE__{} = state, ref) do
    spawn_next_batch(%__MODULE__{state | task_ref_to_batch: Map.delete(state.task_ref_to_batch, ref)})
  end

  # Removes a task from the state and schedules it (or another chunk of data) for retry.
  #
  # This function is called when a task needs to be retried, either due to failure
  # or explicit retry request. It removes the task reference from the state and
  # pushes either a new batch of entries (if provided) or the original batch back
  # to the queue for reprocessing.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  # - `ref`: The reference of the task to be removed and retried.
  # - `new_batch`: Optional. A new batch of entries to be processed instead of
  #   the original batch. Defaults to nil.
  #
  # ## Returns
  # Updated state after removing the task and pushing entries for retry.
  @spec drop_task_and_retry(
          %__MODULE__{task_ref_to_batch: %{reference() => [term(), ...]}},
          reference(),
          entries() | nil
        ) :: t()
  defp drop_task_and_retry(%__MODULE__{task_ref_to_batch: task_ref_to_batch} = state, ref, new_batch \\ nil) do
    batch = Map.fetch!(task_ref_to_batch, ref)

    # Question: should we push the data to the queue first and then spawn the next batch?
    state
    |> drop_task(ref)
    |> push_back(new_batch || batch)
  end

  # Adds new entries to the appropriate buffer in the current state.
  #
  # This function has the following behaviors depending on the input:
  # 1. If `front?` is true, it prepends the entries to the current front buffer.
  # 2. If `front?` is false, it prepends the entries to the current buffer.
  # 3. If entries is empty, it returns the original state unchanged.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  # - `entries`: A list of new entries to be added to a buffer.
  # - `front?`: A boolean indicating whether to add to the front buffer (true) or
  #   the regular buffer (false).
  #
  # ## Returns
  # An updated state with the new entries added to the appropriate buffer, or
  # the original state if entries is empty.
  #
  # ## Notes
  # When entries are added, they are prepended as a single list element to
  # the existing buffer, maintaining the order of batches.
  @spec buffer_entries(t(), [], boolean()) :: t()
  defp buffer_entries(state, [], _front?), do: state

  @spec buffer_entries(t(), nonempty_list(), true) :: t()
  defp buffer_entries(%__MODULE__{} = state, entries, true) do
    %__MODULE__{state | current_front_buffer: [entries | state.current_front_buffer]}
  end

  @spec buffer_entries(t(), nonempty_list(), false) :: t()
  defp buffer_entries(%__MODULE__{} = state, entries, false) do
    %__MODULE__{state | current_buffer: [entries | state.current_buffer]}
  end

  # Initiates the initial streaming process for the BufferedTask.
  #
  # This function has two clauses:
  # 1. When an init_task is already in progress, it schedules the next buffer flush.
  # 2. When no init_task is in progress, it starts a new async task to initialize
  #    the stream.
  #
  # The initialization process:
  # - Calls the `init/3` function of the callback module.
  # - Accumulates entries into chunks up to the maximum batch size.
  # - Pushes full chunks to the queue, triggering processing of queue data.
  # - Processes any remaining entries after initialization. These are entries that
  #   were accumulated but didn't form a complete chunk. They are pushed to the
  #   queue, ensuring no data is lost, and trigger processing of queue data (which
  #   may include these entries).
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  #
  # ## Returns
  # - Updated `state` with the new `init_task` reference and scheduled buffer flush.
  @spec do_initial_stream(%__MODULE__{
          init_task: reference() | :complete | :delay | nil,
          callback_module: module(),
          max_batch_size: pos_integer(),
          task_supervisor: GenServer.name(),
          metadata: Logger.metadata()
        }) :: t()
  defp do_initial_stream(%__MODULE__{init_task: init_task} = state) when is_reference(init_task) do
    schedule_next_buffer_flush(state)
  end

  defp do_initial_stream(
         %__MODULE__{
           callback_module: callback_module,
           callback_module_state: callback_module_state,
           max_batch_size: max_batch_size,
           task_supervisor: task_supervisor,
           metadata: metadata
         } = state
       ) do
    parent = self()

    task =
      Task.Supervisor.async(task_supervisor, fn ->
        Logger.metadata(metadata)

        {0, []}
        |> callback_module.init(
          # It accumulates entries into chunks until the maximum chunk size is
          # reached, then pushes the chunk to the queue and trigger processing
          # of the next batch of the queue's data. The chunk size is set to
          # ensure it doesn't exceed the batch size used in `spawn_next_batch`,
          # guaranteeing that all data in the queue can be included in
          # processing batches.
          fn
            entry, {len, acc} when len + 1 >= max_batch_size ->
              entries = Enum.reverse([entry | acc])
              push_back(parent, entries)

              {0, []}

            entry, {len, acc} ->
              {len + 1, [entry | acc]}
          end,
          callback_module_state
        )
        |> catchup_remaining(max_batch_size, parent)
      end)

    schedule_next_buffer_flush(%__MODULE__{state | init_task: task.ref})
  end

  # Processes any remaining entries after the initial streaming operation by
  # pushing them to the back of the queue and triggering processing of a batch of
  # the queue's data.
  @spec catchup_remaining({non_neg_integer(), list()}, pos_integer(), pid()) :: :ok
  defp catchup_remaining(chunk_with_length, max_batch_size, pid)

  defp catchup_remaining({0, []}, _max_batch_size, _pid), do: :ok

  defp catchup_remaining({len, batch}, max_batch_size, pid)
       when is_integer(len) and is_list(batch) and is_integer(max_batch_size) and is_pid(pid) do
    push_back(pid, Enum.reverse(batch))

    :ok
  end

  # Pushes entries to the back of the queue.
  #
  # This function has two behaviors depending on the input:
  # 1. If given a PID, it sends a :push_back message to the specified process.
  # 2. If given the current state, it adds entries to the back of the bound queue.
  #
  # ## Parameters
  # - `pid`: A PID of a BufferedTask process.
  # - `state`: The current state of the BufferedTask.
  # - `entries`: A list of entries to be pushed to the back of the queue.
  #
  # ## Returns
  # - When given a PID: The result of the GenServer call (any term).
  # - When given the current state: The updated state with a potentially
  #   modified bound queue.
  @spec push_back(pid(), list()) :: term()
  defp push_back(pid, entries) when is_pid(pid) and is_list(entries) do
    GenServer.call(pid, {:push_back, entries})
  end

  @spec push_back(t(), list()) :: t()
  defp push_back(%__MODULE__{} = state, entries), do: push(state, entries, false)

  # Pushes entries to the front of the queue.
  #
  # This function has two behaviors depending on the input:
  # 1. If given a PID, it sends a :push_front message to the specified process.
  # 2. If given the current state, it adds entries to the front of the bound queue.
  #
  # ## Parameters
  # - `pid`: A PID of a BufferedTask process.
  # - `state`: The current state of the BufferedTask.
  # - `entries`: A list of entries to be pushed to the front of the queue.
  #
  # ## Returns
  # - When given a PID: The result of the GenServer call (any term).
  # - When given the current state: The updated state with a potentially
  #   modified bound queue.
  @spec push_front(pid(), list()) :: term()
  defp push_front(pid, entries) when is_pid(pid) and is_list(entries) do
    GenServer.call(pid, {:push_front, entries})
  end

  @spec push_front(t(), list()) :: t()
  defp push_front(%__MODULE__{} = state, entries), do: push(state, entries, true)

  # Pushes a list of entries into the bound queue of the state.
  #
  # If all entries are successfully added, the function simply updates the state
  # with the new bound queue. If the bound queue reaches its maximum size before
  # all entries can be added, the function discards the remaining entries and
  # logs a warning.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  # - `entries`: A list of entries to be pushed into the bound queue.
  # - `front?`: A boolean flag. If true, pushes to the front; if false, pushes to the back.
  #
  # ## Returns
  # The updated state with the new entries added to the bound queue.
  @spec push(%__MODULE__{bound_queue: BoundQueue.t(term())}, list(), boolean()) :: t()
  defp push(%__MODULE__{bound_queue: bound_queue} = state, entries, front?) when is_list(entries) do
    new_bound_queue =
      case push_until_maximum_size(bound_queue, entries, front?) do
        {new_bound_queue, []} ->
          new_bound_queue

        {%BoundQueue{maximum_size: maximum_size} = new_bound_queue, remaining_entries} ->
          Logger.warning(fn ->
            [
              "BufferedTask ",
              process(self()),
              " bound queue is at maximum size (",
              to_string(maximum_size),
              ") and ",
              remaining_entries |> Enum.count() |> to_string(),
              " entries could not be added."
            ]
          end)

          new_bound_queue
      end

    %__MODULE__{state | bound_queue: new_bound_queue}
  end

  # Pushes entries into a BoundQueue until its maximum size is reached.
  #
  # This function attempts to add entries to either the front or back of the
  # BoundQueue, depending on the boolean flag. It continues adding entries
  # until the queue reaches its maximum size or all entries have been added.
  #
  # The order of entries is preserved during the push operation. When pushing
  # to the front, the first entry in the list becomes the first in the queue.
  # Conversely, when pushing to the back, the last entry in the list becomes
  # the last in the queue.
  #
  # ## Parameters
  # - `bound_queue`: The BoundQueue to push entries into.
  # - `entries`: A list of entries to be pushed into the queue.
  # - `front?`: A boolean flag. If true, pushes to the front; if false, pushes to the back.
  #
  # ## Returns
  # A tuple containing:
  # - The updated BoundQueue with new entries added.
  # - A list of remaining entries that couldn't be pushed due to size limitations.
  @spec push_until_maximum_size(BoundQueue.t(term()), list(), boolean()) :: {BoundQueue.t(term()), list()}
  defp push_until_maximum_size(bound_queue, entries, true),
    do: BoundQueue.push_front_until_maximum_size(bound_queue, entries)

  defp push_until_maximum_size(bound_queue, entries, false),
    do: BoundQueue.push_back_until_maximum_size(bound_queue, entries)

  # Takes a batch of entries from the current state or BoundQueue.
  #
  # This function has three implementations to handle different input types
  # and use cases:
  #
  # 1. When given the current state of the BufferedTask:
  #    - Takes a batch of entries based on the `max_batch_size`.
  #    - Returns the batch and an updated state.
  #
  # 2. When given a BoundQueue and `max_batch_size`:
  #    - Initializes the recursive batch-taking process.
  #    - Returns the batch and the updated BoundQueue.
  #
  # 3. Recursive implementation (private):
  #    - Recursively takes entries from the BoundQueue.
  #    - Accumulates entries until the requested number is reached or the queue is empty.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  # - `bound_queue`: The BoundQueue to take entries from.
  # - `max_batch_size`: The maximum number of entries to take.
  # - `remaining`: The number of entries still to be taken (in recursive calls).
  # - `acc`: The accumulator for entries already taken (in recursive calls).
  #
  # ## Returns
  # Depending on the implementation:
  # 1. `{batch, updated_state}`
  # 2. `{batch, updated_bound_queue}`
  # 3. `{reversed_batch, updated_bound_queue}`
  #
  # Where:
  # - `batch`: A list of taken entries in their original order.
  # - `updated_state`: The state with an updated BoundQueue.
  # - `updated_bound_queue`: The BoundQueue with taken entries removed.
  #
  # ## Notes
  # - The function ensures that no more than `max_batch_size` entries are taken.
  # - If the queue becomes empty before taking all requested entries, the function
  #   returns with whatever entries it has accumulated so far.
  @spec take_batch(%__MODULE__{bound_queue: BoundQueue.t(term()), max_batch_size: non_neg_integer()}) ::
          {entries(), t()}
  defp take_batch(%__MODULE__{bound_queue: bound_queue, max_batch_size: max_batch_size} = state) do
    {batch, new_bound_queue} = take_batch(bound_queue, max_batch_size)
    {batch, %__MODULE__{state | bound_queue: new_bound_queue}}
  end

  @spec take_batch(BoundQueue.t(term()), non_neg_integer()) :: {entries(), BoundQueue.t(term())}
  defp take_batch(%BoundQueue{} = bound_queue, max_batch_size) do
    take_batch(bound_queue, max_batch_size, [])
  end

  @spec take_batch(BoundQueue.t(term()), non_neg_integer(), list()) :: {entries(), BoundQueue.t(term())}
  defp take_batch(%BoundQueue{} = bound_queue, 0, acc) do
    {Enum.reverse(acc), bound_queue}
  end

  defp take_batch(%BoundQueue{} = bound_queue, remaining, acc) do
    case BoundQueue.pop_front(bound_queue) do
      {:ok, {entry, new_bound_queue}} ->
        take_batch(new_bound_queue, remaining - 1, [entry | acc])

      {:error, :empty} ->
        take_batch(bound_queue, 0, acc)
    end
  end

  # Schedules the next operation based on the current state of the BufferedTask.
  #
  # This function is called after triggering processing a batch of queue's data
  # to determine the next action, helping maintain a continuous flow of work in
  # the BufferedTask.
  #
  # This function has two clauses:
  # 1. When the queue is empty, there are no ongoing tasks, and polling is enabled,
  #    it re-initializes the stream to fetch more work.
  # 2. In all other cases, it schedules the next buffer flush.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  #
  # ## Returns
  # - Updated `state` after scheduling the next operation.
  @spec schedule_next(%__MODULE__{
          poll: boolean(),
          bound_queue: BoundQueue.t(term()),
          task_ref_to_batch: %{reference() => [term(), ...]}
        }) :: t()
  defp schedule_next(
         %__MODULE__{poll: true, init_task: init_task, bound_queue: %BoundQueue{size: 0}, task_ref_to_batch: tasks} =
           state
       )
       when tasks == %{} and init_task in [:complete, nil] do
    Process.send_after(self(), :initial_stream, state.init_task_delay)
    schedule_next_buffer_flush(%{state | init_task: :delay})
  end

  defp schedule_next(%__MODULE__{} = state) do
    schedule_next_buffer_flush(state)
  end

  # Schedules the next buffer flush based on the flush_interval.
  #
  # If the flush_interval is set to `:infinity`, no flush is scheduled and the
  # state is returned unchanged. Otherwise, a timer is set to send a `:flush`
  # message after the specified interval.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask. Must include `:flush_interval`.
  #
  # ## Returns
  # - The updated state with the new flush_timer if a flush was scheduled,
  #   or the unchanged state if flush_interval is :infinity.
  @spec schedule_next_buffer_flush(%__MODULE__{flush_interval: timeout() | :infinity}) :: t()
  defp schedule_next_buffer_flush(%__MODULE__{} = state) do
    if state.flush_interval == :infinity do
      state
    else
      timer = Process.send_after(self(), :flush, state.flush_interval)
      %__MODULE__{state | flush_timer: timer}
    end
  end

  # Registers the current process as shrinkable with the memory monitor if one is provided.
  #
  # This function checks the options for a `:memory_monitor`. If present, it registers
  # the current process with the monitor as a shrinkable process. This allows the
  # memory monitor to request the process to reduce its memory usage if needed.
  #
  # ## Parameters
  # - `options`: A keyword list of options that may include :memory_monitor.
  #
  # ## Returns
  # - `:ok` if no memory monitor is provided or after successful registration.
  #
  # ## Side Effects
  # - If a memory monitor is provided, the current process is registered as
  #   shrinkable with that monitor.
  defp shrinkable(options) do
    case Keyword.get(options, :memory_monitor) do
      nil -> :ok
      memory_monitor -> Memory.Monitor.shrinkable(memory_monitor)
    end
  end

  # Spawns the next batch processing task.
  #
  # This function checks if a new task can be spawned based on the current
  # number of running tasks and the availability of entries in the bound queue.
  # If conditions are met, it takes a batch from the bound queue and spawns
  # a new task to process it. As soon as the task is spawned, the
  # `task_ref_to_batch` map is updated to enable retrying the task if needed.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  #
  # ## Returns
  # - An updated state if a new task was spawned. Otherwise, the original state
  #   is returned.
  @spec spawn_next_batch(%__MODULE__{
          bound_queue: BoundQueue.t(term()),
          callback_module: module(),
          callback_module_state: term(),
          max_concurrency: non_neg_integer(),
          task_ref_to_batch: %{reference() => [term(), ...]},
          task_supervisor: GenServer.name(),
          metadata: Logger.metadata()
        }) :: t()
  defp spawn_next_batch(
         %__MODULE__{
           bound_queue: bound_queue,
           callback_module: callback_module,
           callback_module_state: callback_module_state,
           max_concurrency: max_concurrency,
           task_ref_to_batch: task_ref_to_batch,
           task_supervisor: task_supervisor,
           metadata: metadata
         } = state
       ) do
    if Enum.count(task_ref_to_batch) < max_concurrency and not Enum.empty?(bound_queue) do
      {batch, new_state} = take_batch(state)

      %Task{ref: ref} =
        Task.Supervisor.async_nolink(task_supervisor, __MODULE__, :log_run, [
          %{
            metadata: metadata,
            callback_module: callback_module,
            batch: batch,
            callback_module_state: callback_module_state
          }
        ])

      %__MODULE__{new_state | task_ref_to_batch: Map.put(task_ref_to_batch, ref, batch)}
    else
      state
    end
  end

  @doc """
    Executes the run callback of the specified module.

    This function is designed to be called asynchronously by `Task.Supervisor`. It
    invokes the `run/2` callback of the specified callback module.

    ## Parameters
    - params: A map containing the following keys:
      - `:metadata`: Keyword list of logging metadata to be set.
      - `:callback_module`: The module that implements the `run/2` callback.
      - `:batch`: A list of items to be processed by the callback.
      - `:callback_module_state`: The current state of the callback module.

    ## Returns
    Returns the result of calling `run/2` on the callback module.

    ## Notes
    This function is public to allow it to be called by `Task.Supervisor`, but it's
    not intended for direct use outside of the BufferedTask context.
  """
  @spec log_run(%{
          metadata: Logger.metadata(),
          callback_module: module(),
          batch: entries(),
          callback_module_state: term()
        }) ::
          any()
  def log_run(%{
        metadata: metadata,
        callback_module: callback_module,
        batch: batch,
        callback_module_state: callback_module_state
      }) do
    Logger.metadata(metadata)
    callback_module.run(batch, callback_module_state)
  end

  # Initiates processing of the next batch of the queue's data after flushing the current buffers.
  #
  # This function ensures that all buffered entries are scheduled for
  # processing by pushing both the regular and front buffers to the queue if they
  # are not empty. Then, it initiates processing of the next batch of the queue's
  # data by spawning a task that will call the `run/2` callback of the callback
  # module, and schedules the next operation.
  #
  # ## Parameters
  # - `state`: The current state of the BufferedTask.
  #
  # ## Returns
  # - Updated `state` after flushing buffers and scheduling next operations.
  @spec flush(%__MODULE__{current_buffer: list(), current_front_buffer: list}) :: t()
  defp flush(%__MODULE__{current_buffer: [], current_front_buffer: []} = state) do
    state
    |> spawn_next_batch()
    |> schedule_next()
  end

  defp flush(%__MODULE__{current_buffer: buffer, current_front_buffer: front_buffer} = state) do
    back_entries = List.flatten(buffer)
    front_entries = List.flatten(front_buffer)

    %__MODULE__{state | current_buffer: [], current_front_buffer: []}
    |> push_back(back_entries)
    |> push_front(front_entries)
    |> flush()
  end

  defp increased_delay, do: Application.get_env(:indexer, :fetcher_init_delay)
end
