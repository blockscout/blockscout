defmodule Explorer.Celo.ContractEvents.Attestations.AttestationIssuerSelectedEvent do
  @moduledoc """
  Struct modelling the AttestationIssuerSelected event from the Attestations Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "AttestationIssuerSelected",
    topic: "0xaf7f470b643316cf44c1f2898328a075e7602945b4f8584f48ba4ad2d8a2ea9d"

  event_param(:identifier, {:bytes, 32}, :indexed)
  event_param(:account, :address, :indexed)
  event_param(:issuer, :address, :indexed)
  event_param(:attestation_request_fee_token, :address, :unindexed)
end
