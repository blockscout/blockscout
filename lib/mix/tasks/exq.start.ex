defmodule Mix.Tasks.Exq.Start do
  @moduledoc "Starts the Exq worker"
  use Mix.Task
  alias Explorer.Repo
  alias Explorer.Scheduler

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
