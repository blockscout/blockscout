# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Context do
  @moduledoc """
  Everything `Explorer.Chain.TokenTransfer.PoisoningAttack.Rules` needs to
  score one token transfer from the point of view of one victim.

  A context is assembled by the detector from the transfer, its transaction
  and the batch-wide lookups, and the rules only read it: they never touch the
  database themselves.
  """

  alias Explorer.Chain.{Hash, Token, TokenTransfer}

  @typedoc """
  What is known about one address taking part in the transfer:

  * `contract?` — the address holds code;
  * `attributed?` — the address is explained (verified contract, named, tagged,
    Safe or EIP-7702 proxy), so flows through it are not suspicious by
    themselves;
  * `verified?` — the address is a verified smart contract.
  """
  @type participant :: %{contract?: boolean(), attributed?: boolean(), verified?: boolean()}

  @typedoc """
  Accepted contracts per normalized asset symbol / name.
  """
  @type known_assets :: %{
          symbols: %{String.t() => MapSet.t(Hash.Address.t())},
          names: %{String.t() => MapSet.t(Hash.Address.t())}
        }

  @typedoc """
  * `token_transfer` — the transfer being scored.
  * `issuer` — sender of the transaction that emitted the transfer, `nil` when
    the transfer has no transaction.
  * `transaction_to` — recipient of that transaction (the contract called).
  * `victim` — the address whose history the transfer may be poisoning.
  * `counterparty` — the other participant of the transfer.
  * `amount` — the fungible amount of the transfer (sum of the amounts of an
    ERC-1155 batch), `nil` for non-fungible transfers.
  * `token` — the token of the transfer, `nil` when not cataloged yet.
  * `transfer_type` — the classification of `Explorer.Chain.get_token_transfer_type/1`.
  * `scam_hashes` — the participants carrying a scam badge.
  * `participants` — what is known about each participant.
  * `recipients` — previous recipients of the victim, `nil` when not loaded.
  * `known_assets` — the known assets index, `nil` when not loaded.
  * `fanout` — distinct participants the issuer touched within the batch.
  """
  @type t :: %__MODULE__{
          token_transfer: TokenTransfer.t(),
          issuer: Hash.Address.t() | nil,
          transaction_to: Hash.Address.t() | nil,
          victim: Hash.Address.t(),
          counterparty: Hash.Address.t(),
          amount: Decimal.t() | nil,
          token: Token.t() | nil,
          transfer_type: :token_burning | :token_minting | :token_spawning | :token_transfer,
          scam_hashes: MapSet.t(Hash.Address.t()),
          participants: %{Hash.Address.t() => participant()},
          recipients: MapSet.t(Hash.Address.t()) | nil,
          known_assets: known_assets() | nil,
          fanout: non_neg_integer()
        }

  defstruct token_transfer: nil,
            issuer: nil,
            transaction_to: nil,
            victim: nil,
            counterparty: nil,
            amount: nil,
            token: nil,
            transfer_type: :token_transfer,
            scam_hashes: MapSet.new(),
            participants: %{},
            recipients: nil,
            known_assets: nil,
            fanout: 0

  @doc """
  What is known about `address_hash`, defaulting to an unknown, unattributed
  externally owned account.
  """
  @spec participant(t(), Hash.Address.t() | nil) :: participant()
  def participant(_context, nil), do: %{contract?: false, attributed?: false, verified?: false}

  def participant(%__MODULE__{participants: participants}, address_hash) do
    Map.get(participants, address_hash, %{contract?: false, attributed?: false, verified?: false})
  end
end
