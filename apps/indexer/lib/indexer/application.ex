defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.{
    CoinBalanceFetcher,
    BlockFetcher,
    InternalTransactionFetcher,
    PendingTransactionFetcher,
    TokenFetcher,
    TokenBalanceFetcher
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
      {Task.Supervisor, name: Indexer.TaskSupervisor},
      {CoinBalanceFetcher, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: CoinBalanceFetcher]]},
      {PendingTransactionFetcher, name: PendingTransactionFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {InternalTransactionFetcher,
       [[json_rpc_named_arguments: json_rpc_named_arguments], [name: InternalTransactionFetcher]]},
      {TokenFetcher, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: TokenFetcher]]},
      {TokenBalanceFetcher, [[json_rpc_named_arguments: json_rpc_named_arguments], [name: TokenBalanceFetcher]]},
      {BlockFetcher.Supervisor, [block_fetcher_supervisor_named_arguments, [name: BlockFetcher.Supervisor]]}
    ]

    opts = [strategy: :one_for_one, name: Indexer.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
