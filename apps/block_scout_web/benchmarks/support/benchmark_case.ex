defmodule BlockScoutWeb.BenchmarkCase do
  @moduledoc """
  This module defines the benchmark case to be used by benchmarks.

  This module provides common setup and utilities for benchmarking,
  similar to ConnCase but optimized for benchmarking needs, including:

  - Database sandbox management
  - Connection building
  - Factory imports
  - Common helpers

  ## Example

  ```elixir
  defmodule BlockScoutWeb.MyBenchmark do
    use BlockScoutWeb.BenchmarkCase

    def run do
      Benchee.run(...)
    end
  end

  # Run the benchmark
  BlockScoutWeb.MyBenchmark.run()
  ```
  """

  defmacro __using__(_opts) do
    caller_file = __CALLER__.file
    path = caller_file |> String.replace(Path.extname(caller_file), ".benchee")

    quote do
      import Explorer.Factory
      import Phoenix.ConnTest

      @endpoint BlockScoutWeb.Endpoint
      @path unquote(path)

      @doc """
      Resets the database for consistent benchmarks
      """
      def reset_db do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo, ownership_timeout: :infinity)
      end

      @doc """
      Gets a Phoenix connection for HTTP request benchmarks
      """
      def get_conn do
        Phoenix.ConnTest.build_conn()
      end

      @doc """
      Setup common benchmark environment
      """
      def benchmark_setup do
        {:ok, _} = Application.ensure_all_started(:block_scout_web)

        :ok
      end
    end
  end
end
