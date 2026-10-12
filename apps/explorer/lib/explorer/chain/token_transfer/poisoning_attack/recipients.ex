# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Recipients do
  @moduledoc """
  The addresses a victim recently sent to: the set the `lookalike_recipient`
  rule compares a counterparty against.

  Two bounded, index-backed lookups make up the set — the latest token
  transfers the victim sent and the latest transactions it signed — so the cost
  per victim stays flat however busy the address is. Only transfers the victim
  initiated itself count: a poisoning transfer is emitted *from* the victim by
  the attacker's contract, and taking it as a genuine send would teach the
  detector the mimic as a known recipient. Zero-value transfers are skipped
  for the same reason.

  Victims are usually poisoned repeatedly, so the set is cached per victim for
  `recipients_cache_ttl`; the block bound of a cache hit is the one of the
  first lookup, a staleness worth at most the TTL.
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, TokenTransfer, Transaction}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.Config

  @cache_name :token_transfer_poisoning_recipients

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @doc """
  The previous recipients of `victim` as of `before_block`, from the cache when
  it holds them.
  """
  @spec fetch(Hash.Address.t(), non_neg_integer(), Config.t(), keyword()) :: MapSet.t(Hash.Address.t())
  def fetch(%Hash{} = victim, before_block, %Config{} = config, options \\ []) do
    if cache_enabled?() do
      ConCache.get_or_store(@cache_name, victim, fn ->
        %ConCache.Item{
          value: query(victim, before_block, config.recipients_limit, options),
          ttl: config.recipients_cache_ttl
        }
      end)
    else
      query(victim, before_block, config.recipients_limit, options)
    end
  end

  @doc """
  The previous recipients of `victim` as of `before_block`, straight from the
  database: the union of its last `limit` sent token transfers and its last
  `limit` signed transactions, without the victim itself.
  """
  @spec query(Hash.Address.t(), non_neg_integer(), pos_integer(), keyword()) :: MapSet.t(Hash.Address.t())
  def query(%Hash{} = victim, before_block, limit, options \\ []) do
    repo = Chain.select_repo(options)

    [
      token_transfer_recipients_query(victim, before_block, limit),
      transaction_recipients_query(victim, before_block, limit)
    ]
    |> Enum.flat_map(&repo.all/1)
    |> MapSet.new()
    |> MapSet.delete(victim)
  end

  @doc false
  @spec token_transfer_recipients_query(Hash.Address.t(), non_neg_integer(), pos_integer()) :: Ecto.Query.t()
  def token_transfer_recipients_query(victim, before_block, limit) do
    from(token_transfer in TokenTransfer,
      join: transaction in assoc(token_transfer, :transaction),
      where: token_transfer.from_address_hash == ^victim,
      where: token_transfer.block_number < ^before_block,
      where: token_transfer.block_consensus == true,
      where: transaction.from_address_hash == ^victim,
      where: is_nil(token_transfer.amount) or token_transfer.amount > 0,
      order_by: [desc: token_transfer.block_number],
      limit: ^limit,
      select: token_transfer.to_address_hash
    )
  end

  @doc false
  @spec transaction_recipients_query(Hash.Address.t(), non_neg_integer(), pos_integer()) :: Ecto.Query.t()
  def transaction_recipients_query(victim, before_block, limit) do
    from(transaction in Transaction,
      where: transaction.from_address_hash == ^victim,
      where: transaction.block_number < ^before_block,
      where: not is_nil(transaction.to_address_hash),
      order_by: [desc_nulls_first: transaction.block_number, desc_nulls_first: transaction.index],
      limit: ^limit,
      select: transaction.to_address_hash
    )
  end

  defp cache_enabled? do
    Application.get_env(:explorer, __MODULE__, [])[:enabled] == true
  end
end
