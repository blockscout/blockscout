defmodule Mix.Tasks.Exq.Start do
  alias Explorer.Repo
  alias Explorer.Scheduler

  use Mix.Task

  @moduledoc "Starts the Exq worker"

  def run(_args) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)
    Repo.start_link()
    Exq.start_link(mode: :default)
    Scheduler.start_link()
    IO.puts "Started Exq"
    :timer.sleep(:infinity)
  end
end
