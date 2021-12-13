alias Explorer.Repo
import Ecto.Query

defmodule SQLHelper do
  def to_string(query), do: Ecto.Adapters.SQL.to_sql(:all, Explorer.Repo, query) |> IO.inspect()
end
