defmodule Explorer.Schema do
  @moduledoc "Common configuration for Explorer schemas."

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.{Changeset, Query}

      @timestamps_opts [
        type: Timex.Ecto.DateTime,
        autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}
      ]
    end
  end
end
