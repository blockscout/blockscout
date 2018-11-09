defmodule BlockScoutWeb.Resolvers.Transaction do
  @moduledoc false

  alias Explorer.Chain

  def get_by(_, %{hash: hash}, _) do
    case Chain.hash_to_transaction(hash) do
      {:ok, transaction} -> {:ok, transaction}
      {:error, :not_found} -> {:error, "Transaction hash #{hash} was not found."}
    end
  end
end
