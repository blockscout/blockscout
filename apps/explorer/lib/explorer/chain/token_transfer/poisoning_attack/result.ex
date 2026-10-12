# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Result do
  @moduledoc """
  The verdict of `Explorer.Chain.TokenTransfer.PoisoningAttack.Rules` for one
  token transfer and one victim.
  """

  alias Explorer.Chain.{Hash, TokenTransfer}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Config

  @typedoc """
  * `score` — sum of the weights of the rules that fired.
  * `rules` — names of the rules that fired, heaviest first.
  * `details` — what each rule matched, keyed by rule name.
  * `suppressed` — names of the rules that would have fired but were explained
    away by an attributed flow or a mint / burn.
  * `victim`, `mimic`, `issuer` — the participants of the attack as seen from
    this verdict; `mimic` is the counterparty whether or not the verdict is
    positive.
  """
  @type t :: %__MODULE__{
          token_transfer: TokenTransfer.t() | nil,
          score: non_neg_integer(),
          rules: [String.t()],
          details: %{String.t() => map()},
          suppressed: [String.t()],
          victim: Hash.Address.t() | nil,
          mimic: Hash.Address.t() | nil,
          issuer: Hash.Address.t() | nil
        }

  defstruct token_transfer: nil,
            score: 0,
            rules: [],
            details: %{},
            suppressed: [],
            victim: nil,
            mimic: nil,
            issuer: nil

  @doc """
  Whether the verdict identifies the transfer as a poisoning attack.
  """
  @spec attack?(t(), Config.t()) :: boolean()
  def attack?(%__MODULE__{score: score}, %Config{score_threshold: threshold}), do: score >= threshold

  @doc """
  Whether the verdict is worth persisting.
  """
  @spec storable?(t(), Config.t()) :: boolean()
  def storable?(%__MODULE__{score: score}, %Config{store_min_score: min_score}), do: score >= min_score

  @doc """
  The row of `Explorer.Chain.TokenTransfer.PoisoningAttack` this verdict
  corresponds to.
  """
  @spec to_attack_params(t()) :: map()
  def to_attack_params(%__MODULE__{token_transfer: %TokenTransfer{} = token_transfer} = result) do
    %{
      block_hash: token_transfer.block_hash,
      log_index: token_transfer.log_index,
      transaction_hash: token_transfer.transaction_hash,
      block_number: token_transfer.block_number,
      token_contract_address_hash: token_transfer.token_contract_address_hash,
      victim_address_hash: result.victim,
      mimic_address_hash: result.mimic,
      issuer_address_hash: result.issuer,
      score: result.score,
      rules: result.rules,
      details: result.details
    }
  end
end
