defmodule NFTMediaHandlerDispatcherInterface.Application do
  @moduledoc """
  This is the `Application` module for `NFTMediaHandlerDispatcherInterface`.
  """
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      NFTMediaHandlerDispatcherInterface
    ]

    opts = [strategy: :one_for_one, name: NFTMediaHandlerDispatcherInterface.Supervisor, max_restarts: 1_000]

    if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
      Supervisor.start_link(children, opts)
    else
      Supervisor.start_link([], opts)
    end
  end
end
