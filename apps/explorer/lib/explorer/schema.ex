defmodule Explorer.Schema do
  @moduledoc "Common configuration for Explorer schemas."

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.{Changeset, Query}

      @timestamps_opts [
        type: :utc_datetime,
        usec: true
      ]
    end
  end
end
