defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.{
    BalanceFetcher,
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
      {BalanceFetcher, name: BalanceFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {PendingTransactionFetcher, name: PendingTransactionFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {InternalTransactionFetcher,
       name: InternalTransactionFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {TokenFetcher, name: TokenFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {TokenBalanceFetcher, name: TokenBalanceFetcher, json_rpc_named_arguments: json_rpc_named_arguments},
      {BlockFetcher.Supervisor, [block_fetcher_supervisor_named_arguments, [name: BlockFetcher.Supervisor]]}
    ]

    opts = [strategy: :one_for_one, name: Indexer.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
