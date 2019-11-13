defmodule Explorer.Chain.Import.Runner.Util do
    @moduledoc """
    Some shared code
    """

    alias Explorer.Chain.Import

    def make_insert_options(key, timeout, %{timestamps: timestamps} = options) do
        options
        |> Map.get(key, %{})
        |> Map.take(~w(on_conflict timeout)a)
        |> Map.put_new(:timeout, timeout)
        |> Map.put(:timestamps, timestamps)
    end

    @type insert_option :: %{
        optional(:on_conflict) => Import.Runner.on_conflict(),
        required(:timeout) => timeout,
        required(:timestamps) => Import.timestamps()
    }

end
