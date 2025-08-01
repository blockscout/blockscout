defmodule Indexer.Application do
  @moduledoc """
  This is the `Application` module for `Indexer`.
  """

  use Application

  alias Indexer.Fetcher.OnDemand.CoinBalance, as: CoinBalanceOnDemand
  alias Indexer.Fetcher.OnDemand.ContractCode, as: ContractCodeOnDemand
  alias Indexer.Fetcher.OnDemand.ContractCreator, as: ContractCreatorOnDemand
  alias Indexer.Fetcher.OnDemand.FirstTrace, as: FirstTraceOnDemand
  alias Indexer.Fetcher.OnDemand.NFTCollectionMetadataRefetch, as: NFTCollectionMetadataRefetchOnDemand
  alias Indexer.Fetcher.OnDemand.TokenBalance, as: TokenBalanceOnDemand
  alias Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch, as: TokenInstanceMetadataRefetchOnDemand
  alias Indexer.Fetcher.OnDemand.TokenTotalSupply, as: TokenTotalSupplyOnDemand
  alias Indexer.Fetcher.TokenInstance.Refetch, as: TokenInstanceRefetch

  alias Indexer.Memory

  @impl Application
  def start(_type, _args) do
    memory_monitor_name = Memory.Monitor

    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)

    pool_size =
      token_instance_fetcher_pool_size(
        Indexer.Fetcher.TokenInstance.Realtime,
        Indexer.Fetcher.TokenInstance.Realtime.Supervisor
      ) +
        token_instance_fetcher_pool_size(
          Indexer.Fetcher.TokenInstance.Retry,
          Indexer.Fetcher.TokenInstance.Retry.Supervisor
        ) +
        token_instance_fetcher_pool_size(
          Indexer.Fetcher.TokenInstance.Sanitize,
          Indexer.Fetcher.TokenInstance.Sanitize.Supervisor
        ) +
        token_instance_fetcher_pool_size(
          Indexer.Fetcher.TokenInstance.Refetch,
          Indexer.Fetcher.TokenInstance.Refetch.Supervisor
        ) +
        token_instance_fetcher_pool_size(Indexer.Fetcher.TokenInstance.SanitizeERC1155, nil) +
        token_instance_fetcher_pool_size(Indexer.Fetcher.TokenInstance.SanitizeERC721, nil) + 1

    # + 1 (above in pool_size calculation) for the Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch

    base_children = [
      :hackney_pool.child_spec(:token_instance_fetcher, max_connections: pool_size),
      {Memory.Monitor, [%{}, [name: memory_monitor_name]]},
      {CoinBalanceOnDemand.Supervisor, [[json_rpc_named_arguments: json_rpc_named_arguments]]},
      {TokenBalanceOnDemand.Supervisor, []},
      {ContractCodeOnDemand.Supervisor, [json_rpc_named_arguments]},
      {ContractCreatorOnDemand.Supervisor, [json_rpc_named_arguments]},
      {NFTCollectionMetadataRefetchOnDemand.Supervisor, [json_rpc_named_arguments]},
      {TokenInstanceMetadataRefetchOnDemand.Supervisor, [json_rpc_named_arguments]},
      {TokenInstanceRefetch.Supervisor, []},
      {TokenTotalSupplyOnDemand.Supervisor, []},
      {FirstTraceOnDemand.Supervisor, [json_rpc_named_arguments]}
    ]

    children =
      if Application.get_env(:indexer, Indexer.Supervisor)[:enabled] do
        Enum.reverse([{Indexer.Supervisor, [%{memory_monitor: memory_monitor_name}]} | base_children])
      else
        base_children
      end

    opts = [
      # If the `Memory.Monitor` dies, it needs all the `Shrinkable`s to re-register, so restart them.
      strategy: :rest_for_one,
      name: Indexer.Application
    ]

    if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Supervisor.start_link([], opts)
    else
      Supervisor.start_link(children, opts)
    end
  end

  defp token_instance_fetcher_pool_size(fetcher, nil) do
    envs = Application.get_env(:indexer, fetcher)

    if envs[:enabled] do
      envs[:concurrency]
    else
      0
    end
  end

  defp token_instance_fetcher_pool_size(fetcher, supervisor) do
    if Application.get_env(:indexer, supervisor)[:disabled?] do
      0
    else
      Application.get_env(:indexer, fetcher)[:concurrency]
    end
  end
end
