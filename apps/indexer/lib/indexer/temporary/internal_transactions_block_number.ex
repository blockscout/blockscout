defmodule Indexer.Temporary.InternalTransactionsBlockNumber do
  @moduledoc """
  Looks for a table `blocks_to_invalidate_wrong_int_txs_collation` specifing
  the `number` of blocks that need to be refetched, removes their consensus and
  refetches and imports them.
  """

  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Ecto.Multi
  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Indexer.Block.Fetcher, as: BlockFetcher
  alias Indexer.BufferedTask
  alias Indexer.Temporary.InternalTransactionsBlockNumber

  @behaviour BufferedTask

  @defaults [
    flush_interval: :timer.seconds(3),
    max_batch_size: 50,
    max_concurrency: 2,
    task_supervisor: Indexer.Temporary.InternalTransactionsBlockNumber.TaskSupervisor,
    metadata: [fetcher: :internal_transactions_block_number]
  ]

  @doc false
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def child_spec([init_options, gen_server_options]) when is_list(init_options) do
    {json_rpc_named_arguments, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless json_rpc_named_arguments do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    block_fetcher = %BlockFetcher{
      # for simplicity use the `import` function of catchup fetcher
      callback_module: Indexer.Block.Catchup.Fetcher,
      json_rpc_named_arguments: json_rpc_named_arguments
    }

    merged_init_options =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, block_fetcher)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    query =
      from(
        s in InternalTransactionsBlockNumber.Schema,
        where: is_nil(s.refetched) or not s.refetched,
        where: not is_nil(s.block_number),
        # goes from latest to newest
        order_by: [desc: s.block_number],
        select: s.block_number
      )

    {:ok, final} = Repo.stream_reduce(query, initial, &reducer.(&1, &2))

    drop_table_when_finished(query)

    final
  rescue
    postgrex_error in Postgrex.Error ->
      # if the table does not exist it just does no work
      case postgrex_error do
        %{postgres: %{code: :undefined_table}} -> {0, []}
        _ -> raise postgrex_error
      end
  end

  # sobelow_skip ["SQL.Query"]
  defp drop_table_when_finished(query) do
    unless Repo.exists?(query) do
      SQL.query!(Repo, "DROP TABLE blocks_to_invalidate_wrong_int_txs_collation", [])
    end
  end

  def clean_affected_data(block_numbers) do
    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi =
      Multi.new()
      |> Multi.run(:remove_block_consensus, fn repo, _ ->
        query =
          from(
            block in Block,
            where: block.number in ^block_numbers,
            # Enforce Block ShareLocks order (see docs: sharelocks.md)
            order_by: [asc: block.hash],
            lock: "FOR UPDATE"
          )

        {_num, result} =
          repo.update_all(
            from(b in Block, join: s in subquery(query), on: b.hash == s.hash),
            set: [consensus: false]
          )

        {:ok, result}
      end)
      |> Multi.run(:update_schema_entries, fn repo, _ ->
        query =
          from(
            s in InternalTransactionsBlockNumber.Schema,
            where: s.block_number in ^block_numbers,
            order_by: [desc: s.block_number],
            lock: "FOR UPDATE"
          )

        {num, _res} =
          repo.update_all(
            from(dtt in InternalTransactionsBlockNumber.Schema,
              join: s in subquery(query),
              on: dtt.block_number == s.block_number
            ),
            set: [refetched: true]
          )

        {:ok, num}
      end)

    Repo.transaction(multi, timeout: :infinity)
  end

  @impl BufferedTask
  def run(block_numbers, block_fetcher) do
    block_numbers
    |> clean_affected_data()
    |> case do
      {:ok, _res} ->
        BlockFetcher.refetch_and_import_blocks(block_numbers, block_fetcher)

      {:error, error} ->
        Logger.error(fn ->
          ["Error while handling internal_transactions with wrong block number: ", inspect(error)]
        end)

        {:retry, block_numbers}
    end
  rescue
    postgrex_error in Postgrex.Error ->
      Logger.error(fn ->
        ["Error while handling internal_transactions with wrong block number: ", inspect(postgrex_error)]
      end)

      {:retry, block_numbers}
  end

  defmodule Schema do
    @moduledoc """
    Schema for the table `blocks_to_invalidate_wrong_int_txs_collation`, used by the refetcher
    """

    use Explorer.Schema

    @type t :: %__MODULE__{
            block_number: Block.block_number(),
            refetched: boolean() | nil
          }

    @primary_key false
    schema "blocks_to_invalidate_wrong_int_txs_collation" do
      field(:block_number, :integer)
      field(:refetched, :boolean)
    end

    def changeset(%__MODULE__{} = with_wrong_int_txs, attrs) do
      with_wrong_int_txs
      |> cast(attrs, [:block_number, :refetched])
      |> validate_required(:block_number)
    end
  end
end
