defmodule Explorer.History.Historian do
  @moduledoc """
  Interface for compiling, saving, and fetching historical records.
  """

  @typedoc """
  Record of historical values for a specific date.
  """
  @type record :: %{
          required(:date) => Date.t(),
          optional(atom()) => any()
        }

  @doc """
  Compile history for a specified amount of units in the past. Units are defined by historian impl
  """
  @callback compile_records(number_of_records :: non_neg_integer()) :: {:ok, [record()]} | :error

  @doc """
  Takes records and saves them to a database or some other data store
  """
  @callback save_records(records :: [record()]) :: integer()

  defmacro __using__(_opts) do
    quote do
      alias Explorer.History.Historian

      def start_link(_) do
        # Expansion:
        # HistoryProcess.start_link(Explorer.History.Process, [:ok, __MODULE__], name: __MODULE__)
        GenServer.start_link(Explorer.History.Process, [:ok, __MODULE__], name: __MODULE__)
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end
    end
  end
end
