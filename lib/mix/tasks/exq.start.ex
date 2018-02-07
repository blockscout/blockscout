defmodule Mix.Tasks.Exq.Start do
  @moduledoc "Starts the Exq worker"
  use Mix.Task
  alias Explorer.Repo
  alias Explorer.Scheduler

  def run(["scheduler"]) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)
    Repo.start_link()
    Scheduler.start_link()
    run()
  end

  def run(_) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)
    Repo.start_link()
    run()
  end

  def run do
    Exq.start_link(mode: :default)
    IO.puts "Started Exq"
    :timer.sleep(:infinity)
  end
end
