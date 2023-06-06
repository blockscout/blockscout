alias Explorer.Repo
import Ecto.Query

defmodule SQLHelper do
  def to_string(query), do: Ecto.Adapters.SQL.to_sql(:all, Explorer.Repo.Local, query) |> IO.inspect()
end

defmodule Clabs.Debug do
  alias Explorer.Chain.Hash.Address

  def token_tx_for_valora_address do
    {:ok,hsh} = Address.cast("0x6131a6d616a4be3737b38988847270a64bc10caa")
    Explorer.GraphQL.token_txtransfers_query_for_address(hsh, 26)
  end
end