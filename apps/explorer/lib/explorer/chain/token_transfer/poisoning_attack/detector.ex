# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Detector do
  @moduledoc """
  Scores a batch of freshly imported token transfers as poisoning attacks.

  Everything the rules need is loaded once per batch — tokens, participants,
  scam badges, the known assets index — and only the victims' recipient sets
  are loaded per transfer, and only for the transfers the trigger rules make
  candidates (see `Explorer.Chain.TokenTransfer.PoisoningAttack.Rules`).

  A transfer is scored once per victim it may have, and the verdict kept is
  the one with the highest score; on a tie the transfer sender is taken as
  the victim, the way a fake outgoing transfer reads.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Cache.{KnownAssets, ScamAddresses}
  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Context, Participants, Recipients, Result, Rules}

  @typedoc """
  One imported token transfer with what the detector cannot read off the
  transfer itself:

  * `issuer` — sender of its transaction, `nil` when it has none;
  * `transaction_to` — recipient of its transaction;
  * `fanout` — distinct addresses the issuer's transfers touched in the batch.
  """
  @type entry :: %{
          token_transfer: TokenTransfer.t(),
          issuer: Hash.Address.t() | nil,
          transaction_to: Hash.Address.t() | nil,
          fanout: non_neg_integer()
        }

  @doc """
  Scores the given entries. Transfers of token types the detection does not
  apply to, mints and burns are left out; every other transfer gets exactly
  one verdict, whatever its score.
  """
  @spec detect([entry()], keyword()) :: [Result.t()]
  def detect(entries, options \\ [])

  def detect([], _options), do: []

  def detect(entries, options) do
    config = Config.load()

    entries = Enum.filter(entries, &scorable?(&1, config))

    if entries == [] do
      []
    else
      tokens = tokens(entries, options)
      participant_hashes = participant_hashes(entries)
      participants = Participants.load(participant_hashes, options)
      scam_hashes = ScamAddresses.scam_hashes(participant_hashes)
      known_assets = KnownAssets.index() || KnownAssets.index_from_override(config.known_assets_override)

      shared = %Context{
        scam_hashes: scam_hashes,
        participants: participants,
        known_assets: known_assets
      }

      entries
      |> Enum.map(&verdict(&1, shared, tokens, config, options))
      |> Enum.reject(&is_nil/1)
    end
  end

  defp scorable?(%{token_transfer: %TokenTransfer{} = token_transfer}, %Config{token_types: token_types}) do
    type = token_transfer.token_type || (match?(%Token{}, token_transfer.token) && token_transfer.token.type)

    is_binary(type) and String.upcase(type) in token_types and
      Chain.get_token_transfer_type(token_transfer) == :token_transfer
  end

  defp scorable?(_entry, _config), do: false

  defp tokens(entries, options) do
    entries
    |> Enum.map(& &1.token_transfer.token_contract_address_hash)
    |> Enum.uniq()
    |> Token.get_by_contract_address_hashes(options)
    |> Map.new(&{&1.contract_address_hash, &1})
  end

  defp participant_hashes(entries) do
    entries
    |> Enum.flat_map(fn %{token_transfer: token_transfer} = entry ->
      [
        token_transfer.from_address_hash,
        token_transfer.to_address_hash,
        token_transfer.token_contract_address_hash,
        entry.issuer,
        entry.transaction_to
      ]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp verdict(%{token_transfer: token_transfer} = entry, %Context{} = shared, tokens, config, options) do
    base = %{
      shared
      | token_transfer: token_transfer,
        issuer: entry.issuer,
        transaction_to: entry.transaction_to,
        amount: amount(token_transfer),
        token: Map.get(tokens, token_transfer.token_contract_address_hash),
        fanout: Map.get(entry, :fanout, 0)
    }

    token_transfer
    |> Rules.orientations(entry.issuer)
    |> Enum.map(fn {victim, counterparty} ->
      base
      |> Map.merge(%{victim: victim, counterparty: counterparty})
      |> with_recipients(config, options)
      |> Rules.evaluate(config)
    end)
    |> Enum.max_by(& &1.score, fn -> nil end)
  end

  # The look-alike lookup is the only per-transfer query, so it is paid for
  # candidates only, and never for a contract: a contract's history is not
  # what a human copies addresses from.
  defp with_recipients(%Context{victim: victim, token_transfer: token_transfer} = context, config, options) do
    if Rules.candidate?(context, config) and not Context.participant(context, victim).contract? do
      %{context | recipients: Recipients.fetch(victim, token_transfer.block_number, config, options)}
    else
      context
    end
  end

  defp amount(%TokenTransfer{amount: %Decimal{} = amount}), do: amount

  defp amount(%TokenTransfer{amounts: [_ | _] = amounts}) do
    Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2)
  end

  defp amount(_token_transfer), do: nil
end
