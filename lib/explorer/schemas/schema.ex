defmodule Explorer.Schema do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      @timestamps_opts [
        type: Timex.Ecto.DateTime,
        autogenerate: {Timex.Ecto.DateTime, :autogenerate, []}
      ]
    end
  end
end
