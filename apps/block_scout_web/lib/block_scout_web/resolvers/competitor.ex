defmodule BlockScoutWeb.Resolvers.Competitor do
    @moduledoc false

    alias Explorer.Chain
#    alias Explorer.Chain.Hash
#    alias Explorer.Chain.Hash.Address

    def get_by(_, _, _) do
        case Chain.query_leaderboard() do
          {:error, :not_found} -> {:error, "Leaderboard broken."}
          {:ok, lst} -> {:ok, Enum.map(lst, fn [address, name, score] -> %{address: "0x" <> Base.encode16(address), identity: name, points: score} end)}
        end
    end

end

