# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.LocalReporter do
  @moduledoc """
  Marks the participants of identified poisoning attacks in the instance's
  own reputation data: the issuer of the attack gets the scam badge, the
  mimic address the public `phishing` tag.

  The victim is never marked, even when it is also the issuer or the mimic
  of the verdict — a self-transfer never gets this far, but the guard costs
  nothing. Both writes are idempotent, so repeated attacks by the same
  addresses are harmless.
  """

  @behaviour Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter

  require Logger

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.Hash
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Result
  alias Explorer.Tags.{AddressTag, AddressToTag}

  @phishing_tag_label "phishing"
  @phishing_tag_display_name "Phishing"

  @spec phishing_tag_label() :: String.t()
  def phishing_tag_label, do: @phishing_tag_label

  @impl true
  @spec report([Result.t()]) :: :ok
  def report([]), do: :ok

  def report(results) do
    results
    |> Enum.flat_map(&issuers/1)
    |> Enum.uniq()
    |> mark_issuers()

    results
    |> Enum.flat_map(&mimics/1)
    |> Enum.uniq()
    |> mark_mimics()

    :ok
  end

  defp issuers(%Result{issuer: %Hash{} = issuer, victim: victim}) when issuer != victim, do: [issuer]
  defp issuers(_result), do: []

  defp mimics(%Result{mimic: %Hash{} = mimic, victim: victim}) when mimic != victim, do: [mimic]
  defp mimics(_result), do: []

  defp mark_issuers([]), do: :ok

  defp mark_issuers(issuers) do
    # `add/1` takes the hashes as strings
    {count, _} = issuers |> Enum.map(&to_string/1) |> ScamBadgeToAddress.add()

    Logger.info("Marked #{count} poisoning attack issuer(s) with the scam badge")
  end

  defp mark_mimics([]), do: :ok

  defp mark_mimics(mimics) do
    case phishing_tag_id() do
      nil ->
        Logger.error("Could not create the #{@phishing_tag_label} tag; poisoning attack mimics are left untagged")

      tag_id ->
        {count, _} = AddressToTag.add_tag_to_addresses(tag_id, mimics)

        Logger.info("Tagged #{count} poisoning attack mimic(s) as #{@phishing_tag_label}")
    end
  end

  defp phishing_tag_id do
    case AddressTag.get_id_by_label(@phishing_tag_label) do
      nil ->
        case AddressTag.set(@phishing_tag_label, @phishing_tag_display_name) do
          {:ok, %AddressTag{id: id}} -> id
          _ -> AddressTag.get_id_by_label(@phishing_tag_label)
        end

      id ->
        id
    end
  end
end
