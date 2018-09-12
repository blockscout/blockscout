defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.{
    Block,
    CoinBalance,
    InternalTransaction,
    PendingTransaction,
    Token,
    TokenBalance
  }

  @impl Application
  def start(_type, _args) do
    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    block_fetcher_supervisor_named_arguments =
      :indexer
      |> Application.get_all_env()
      |> Keyword.take(
        ~w(blocks_batch_size blocks_concurrency block_interval json_rpc_named_arguments receipts_batch_size
           receipts_concurrency subscribe_named_arguments)a
      )
      |> Enum.into(%{})

    children = [
      {CoinBalance.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: CoinBalance.Supervisor]]},
      {PendingTransaction.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments], [name: PendingTransactionFetcher]]},
      {InternalTransaction.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments], [name: InternalTransaction.Supervisor]]},
      {Token.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: Token.Supervisor]]},
      {TokenBalance.Supervisor,
       [[json_rpc_named_arguments: json_rpc_named_arguments], [name: TokenBalance.Supervisor]]},
      {Block.Supervisor, [block_fetcher_supervisor_named_arguments, [name: Block.Supervisor]]}
    ]

    opts = [strategy: :one_for_one, name: Indexer.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
