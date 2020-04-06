defmodule BlockScoutWeb.Resolvers.CeloClaim do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.{CeloAccount}

  def get_by(_, %{hash: hash}, _) do
    {:ok, Chain.get_celo_claims(hash)}
  end

  def get_by(%CeloAccount{address: hash}, _, _) do
    {:ok, Chain.get_celo_claims(hash)}
  end

end
