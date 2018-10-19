defmodule Indexer.Shrinkable.Supervisor do
  @moduledoc """
  Supervisor of all supervision trees that depend on `Indexer.Alarm.Supervisor`.
  """

  use Supervisor

  alias Indexer.{
    Block,
    CoinBalance,
    InternalTransaction,
    PendingTransaction,
    Token,
    TokenBalance,
    TokenTransfer
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

    block_fetcher_supervisor_named_arguments =
      :indexer
      |> Application.get_all_env()
      |> Keyword.take(
        ~w(blocks_batch_size blocks_concurrency block_interval json_rpc_named_arguments receipts_batch_size
           receipts_concurrency subscribe_named_arguments)a
      )
      |> Enum.into(%{})
      |> Map.put(:memory_monitor, memory_monitor)

    Supervisor.init(
      [
        {CoinBalance.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments], [name: CoinBalance.Supervisor]]},
        {PendingTransaction.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments], [name: PendingTransactionFetcher]]},
        {InternalTransaction.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments], [name: InternalTransaction.Supervisor]]},
        {Token.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: Token.Supervisor]]},
        {TokenBalance.Supervisor,
         [[json_rpc_named_arguments: json_rpc_named_arguments], [name: TokenBalance.Supervisor]]},
        {Block.Supervisor, [block_fetcher_supervisor_named_arguments, [name: Block.Supervisor]]},
        {TokenTransfer.Uncataloged.Supervisor, [[], [name: TokenTransfer.Uncataloged.Supervisor]]}
      ],
      strategy: :one_for_one
    )
  end
end
