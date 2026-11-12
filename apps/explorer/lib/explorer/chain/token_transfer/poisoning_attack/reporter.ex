# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter do
  @moduledoc """
  Where identified poisoning attacks are reported to, so that the mimic and
  the issuer get marked wherever the instance keeps its reputation data.

  `Explorer.Chain.TokenTransfer.PoisoningAttack.LocalReporter` writes the
  instance's own scam badges and public tags; a reporter talking to an
  external service, such as the Metadata microservice, plugs in through the
  `reporter` key of the `Explorer.Chain.TokenTransfer.PoisoningAttack`
  application environment.
  """

  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Result

  @doc """
  Reports the given attacks. Every result is a positive verdict; the
  reporter decides what to do with its `victim`, `mimic` and `issuer`.
  """
  @callback report([Result.t()]) :: :ok
end
