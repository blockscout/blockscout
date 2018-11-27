defmodule EthereumJSONRPC.FetchedBeneficiary do
  @moduledoc """
  A single balance request params for the beneficiary of a block.
  """

  @type params :: %{address_hash: EthereumJSONRPC.hash(), block_number: non_neg_integer()}
  @type error :: %{code: integer(), message: String.t(), data: %{block_number: non_neg_integer()}}
end
