defmodule Explorer.Etherscan.RPC do
  @moduledoc """
  This module contains functions for working with mimicking of ETH RPC.

  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block

  @spec max_non_consensus_block_number(integer | nil) :: {:ok, Block.block_number()} | {:error, :not_found}
  def max_non_consensus_block_number(max_consensus_block_number \\ nil) do
    max =
      if max_consensus_block_number do
        {:ok, max_consensus_block_number}
      else
        Chain.max_consensus_block_number()
      end

    case max do
      {:ok, number} ->
        query =
          from(block in Block,
            where: block.consensus == false,
            where: block.number > ^number
          )

        query
        |> Repo.replica().aggregate(:max, :number)
        |> case do
          nil -> {:error, :not_found}
          number -> {:ok, number}
        end
    end
  end
end
