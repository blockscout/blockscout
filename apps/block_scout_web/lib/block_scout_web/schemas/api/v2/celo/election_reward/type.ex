defmodule BlockScoutWeb.Schemas.API.V2.Celo.ElectionReward.Type do
  @moduledoc false
  require OpenApiSpex

  alias Explorer.Chain.Celo.ElectionReward

  # Uses `type_enum_with_legacy/0` instead of `types/0` so that
  # CastAndValidate accepts both the canonical underscore form
  # ("delegated_payment") and the legacy hyphenated URL form
  # ("delegated-payment"). See `ElectionReward.type_enum_with_legacy/0`
  # for details.
  OpenApiSpex.schema(%{
    type: :string,
    nullable: false,
    enum: ElectionReward.type_enum_with_legacy(),
    title: "CeloElectionRewardType"
  })
end
