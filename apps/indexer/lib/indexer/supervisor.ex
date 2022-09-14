defmodule Indexer.Supervisor do
  @moduledoc """
  Supervisor of all indexer worker supervision trees
  """

  use Supervisor

  alias Indexer.{
    Block,
    PendingOpsCleaner,
    PendingTransactionsSanitizer
  }

  alias Indexer.Block.{Catchup, Realtime}

  alias Indexer.Fetcher.{
    BlockReward,
    CoinBalance,
    CoinBalanceOnDemand,
    ContractCode,
    EmptyBlocksSanitizer,
    InternalTransaction,
    PendingTransaction,
    ReplacedTransaction,
    Token,
    TokenBalance,
    TokenInstance,
    TokenTotalSupplyOnDemand,
    TokenUpdater,
    UncleBlock,
    CosmosTxHash
  }

  alias Indexer.Temporary.{
    BlocksTransactionsMismatch,
    UncatalogedTokenTransfers,
    UnclesWithoutIndex
  }

  def child_spec([]) do
    child_spec([[]])
  end

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(arguments, gen_server_options \\ []) do
    Supervisor.start_link(__MODULE__, arguments, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl Supervisor
  def init(%{memory_monitor: memory_monitor}) do
    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    named_arguments =
      :indexer
      |> Application.get_all_env()
      |> Keyword.take(
        ~w(blocks_batch_size blocks_concurrency block_interval json_rpc_named_arguments receipts_batch_size
           receipts_concurrency subscribe_named_arguments realtime_overrides)a
      )
      |> Enum.into(%{})
      |> Map.put(:memory_monitor, memory_monitor)
      |> Map.put_new(:realtime_overrides, %{})

    %{
      block_interval: block_interval,
      realtime_overrides: realtime_overrides,
      subscribe_named_arguments: subscribe_named_arguments
    } = named_arguments

    block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval blocks_concurrency memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Block.Fetcher.new()

    realtime_block_fetcher =
      named_arguments
      |> Map.drop(~w(block_interval blocks_concurrency memory_monitor subscribe_named_arguments realtime_overrides)a)
      |> Map.merge(Enum.into(realtime_overrides, %{}))
      |> Block.Fetcher.new()

    realtime_subscribe_named_arguments = realtime_overrides[:subscribe_named_arguments] || subscribe_named_arguments

    realtime_fetcher =
      if Application.get_env(:indexer, Realtime.Supervisor)[:enabled] do
        [
          {Realtime.Supervisor,
           [
             %{block_fetcher: realtime_block_fetcher, subscribe_named_arguments: realtime_subscribe_named_arguments},
             [name: Realtime.Supervisor]
           ]}
        ]
      else
        []
      end

    basic_fetchers = [
      # Root fetchers
      {Catchup.Supervisor,
       [
         %{block_fetcher: block_fetcher, block_interval: block_interval, memory_monitor: memory_monitor},
         [name: Catchup.Supervisor]
       ]},

      # Async catchup fetchers
      {UncleBlock.Supervisor, [[block_fetcher: block_fetcher, memory_monitor: memory_monitor]]},
      {BlockReward.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {InternalTransaction.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {CoinBalance.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {Token.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {TokenInstance.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {ContractCode.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {TokenBalance.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {TokenUpdater.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {CosmosTxHash.Supervisor, [[memory_monitor: memory_monitor]]},
      {ReplacedTransaction.Supervisor, [[memory_monitor: memory_monitor]]},

      # Out-of-band fetchers
      {CoinBalanceOnDemand.Supervisor, [json_rpc_named_arguments]},
      {EmptyBlocksSanitizer.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]},
      {TokenTotalSupplyOnDemand.Supervisor, [json_rpc_named_arguments]},
      {PendingTransactionsSanitizer, [[json_rpc_named_arguments: json_rpc_named_arguments]]},

      # Temporary workers
      {UncatalogedTokenTransfers.Supervisor, [[]]},
      {UnclesWithoutIndex.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {BlocksTransactionsMismatch.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments, memory_monitor: memory_monitor]]},
      {PendingOpsCleaner, [[], []]}
    ]

    all_fetchers =
      [
        {PendingTransaction.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]}
      ] ++
        realtime_fetcher ++
        basic_fetchers

    Supervisor.init(
      all_fetchers,
      strategy: :one_for_one
    )
  end
end
