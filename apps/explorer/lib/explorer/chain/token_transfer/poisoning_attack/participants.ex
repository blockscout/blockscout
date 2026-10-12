# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Participants do
  @moduledoc """
  What is known about the addresses taking part in a batch of token
  transfers, loaded in a handful of batched queries.

  An address is *attributed* — its flows are explained, so a sender mismatch
  through it is not suspicious — when it is a verified contract, carries a
  public tag, or is a Safe or an EIP-7702 delegated account. Verification is a
  weak attribution: an attacker can verify a contract too, which is why it only
  silences the sender signals and never the look-alike or scam rules.
  """

  import Ecto.Query, only: [distinct: 2, select: 3, where: 3]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Context
  alias Explorer.Tags.AddressToTag

  @attributed_proxy_types [:master_copy, :eip7702]

  @doc """
  Loads the participants' facts for the given addresses. Addresses unknown to
  the database are reported as plain externally owned accounts.
  """
  @spec load([Hash.Address.t()], keyword()) :: %{Hash.Address.t() => Context.participant()}
  def load(address_hashes, options \\ [])

  def load([], _options), do: %{}

  def load(address_hashes, options) do
    repo = Chain.select_repo(options)
    hashes = Enum.uniq(address_hashes)

    contracts = contracts(hashes, repo)
    verified = verified(hashes, repo)
    tagged = tagged(hashes, repo)
    proxies = attributed_proxies(hashes, repo)

    Map.new(hashes, fn hash ->
      verified? = MapSet.member?(verified, hash)

      {hash,
       %{
         contract?: MapSet.member?(contracts, hash),
         verified?: verified?,
         attributed?: verified? or MapSet.member?(tagged, hash) or MapSet.member?(proxies, hash)
       }}
    end)
  end

  defp contracts(hashes, repo) do
    Address
    |> where([address], address.hash in ^hashes and not is_nil(address.contract_code))
    |> select([address], address.hash)
    |> repo.all()
    |> MapSet.new()
  end

  defp verified(hashes, repo) do
    SmartContract
    |> where([contract], contract.address_hash in ^hashes)
    |> select([contract], contract.address_hash)
    |> repo.all()
    |> MapSet.new()
  end

  defp tagged(hashes, repo) do
    AddressToTag
    |> where([tag], tag.address_hash in ^hashes)
    |> distinct(true)
    |> select([tag], tag.address_hash)
    |> repo.all()
    |> MapSet.new()
  end

  defp attributed_proxies(hashes, repo) do
    Implementation
    |> where([proxy], proxy.proxy_address_hash in ^hashes and proxy.proxy_type in ^@attributed_proxy_types)
    |> select([proxy], proxy.proxy_address_hash)
    |> repo.all()
    |> MapSet.new()
  end
end
