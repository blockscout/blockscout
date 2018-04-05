defmodule Mix.Tasks.Exq.Start do
  @moduledoc "Starts the Exq worker"
  use Mix.Task

  alias Explorer.{Repo, Scheduler}

  def run(["scheduler"]) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
    Exq.start_link(mode: :enqueuer)
    Scheduler.start_link()
    :timer.sleep(:infinity)
  end

  def run(_) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
    Exq.start_link(mode: :default)
    :timer.sleep(:infinity)
  end
end
