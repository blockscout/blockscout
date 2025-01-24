defmodule NFTMediaHandler.Application do
  @moduledoc """
  This is the `Application` module for `NFTMediaHandler`.
  """
  use Application

  @impl Application
  def start(_type, _args) do
    File.mkdir(Application.get_env(:nft_media_handler, :tmp_dir))

    base_children = [
      Supervisor.child_spec({Task.Supervisor, name: NFTMediaHandler.TaskSupervisor}, id: NFTMediaHandler.TaskSupervisor),
      NFTMediaHandler.Dispatcher
    ]

    children =
      if Application.get_env(:nft_media_handler, :standalone_media_worker?) do
        [
          NFTMediaHandler.DispatcherInterface
          | base_children
        ]
      else
        base_children
      end

    opts = [strategy: :one_for_one, name: NFTMediaHandler.Supervisor, max_restarts: 1_000]

    if Application.get_env(:nft_media_handler, :enabled?) &&
         (!Application.get_env(:nft_media_handler, :remote?) ||
            (Application.get_env(:nft_media_handler, :remote?) && Application.get_env(:nft_media_handler, :worker?))) do
      Supervisor.start_link(children, opts)
    else
      Supervisor.start_link([], opts)
    end
  end
end
