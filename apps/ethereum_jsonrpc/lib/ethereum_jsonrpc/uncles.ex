defmodule EthereumJSONRPC.Uncles do
  @moduledoc """
  List of [uncles](https://github.com/ethereum/wiki/wiki/Glossary#ethereum-blockchain).  Uncles are blocks that didn't
  make the main chain due to them being validated slightly behind what became the main chain.
  """

  alias EthereumJSONRPC.Uncle

  @type elixir :: [Uncle.elixir()]
  @type params :: [Uncle.params()]

  @doc """
  Converts each entry in `elixir` to params used in `Explorer.Chain.Uncle.changeset/2`.

      iex> EthereumJSONRPC.Uncles.elixir_to_params(
      ...>   [
      ...>     %{
      ...>       "hash" => "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311",
      ...>       "nephewHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>       "index" => 0
      ...>     }
      ...>    ]
      ...> )
      [
        %{
          uncle_hash: "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311",
          nephew_hash: "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
          index: 0
        }
      ]

  """
  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Uncle.elixir_to_params/1)
  end
end
