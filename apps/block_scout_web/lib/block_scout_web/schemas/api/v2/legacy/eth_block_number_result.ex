defmodule BlockScoutWeb.Schemas.API.V2.Legacy.EthBlockNumberResult do
  @moduledoc false
  require OpenApiSpex

  # nullable: true is kept defensively. In practice, BlockNumber.get_max/0
  # delegates to Block.fetch_max_block_number/0 which returns Repo.one(query) || 0
  # (with a rescue that also returns 0), so the v1 code path never produces a null
  # result. The field is marked nullable to remain accurate if the underlying
  # implementation ever changes.
  OpenApiSpex.schema(%{
    type: :string,
    pattern: ~r/^0x[0-9a-fA-F]+$/,
    nullable: true,
    description:
      "Hex-encoded latest block number on the chain. " <>
        "Nullable in the schema for defensive reasons; always present in practice."
  })
end
