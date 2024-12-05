defmodule NFTMediaHandlerDispatcher.Application do
  @moduledoc """
  This is the `Application` module for `NFTMediaHandlerDispatcher`.
  """
  use Application

  @impl Application
  def start(_type, _args) do
    base_children = [
      NFTMediaHandlerDispatcher.Queue
    ]

    children =
      if Application.get_env(:nft_media_handler, NFTMediaHandlerDispatcher.Backfiller)[:enabled?] do
        [NFTMediaHandlerDispatcher.Backfiller | base_children]
      else
        base_children
      end

    opts = [strategy: :one_for_one, name: NFTMediaHandlerDispatcher.Supervisor, max_restarts: 1_000]

    if Application.get_env(:nft_media_handler, :enabled?) && !Application.get_env(:nft_media_handler, :worker?) do
      Supervisor.start_link(children, opts)
    else
      Supervisor.start_link([], opts)
    end
  end
end
