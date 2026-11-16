# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeErc404Tokens do
  @moduledoc """
  Finds ERC-404 tokens which were indexed as ERC-721 or ERC-20 ones and converts
  their stored data with `Explorer.Chain.Token.Erc404.convert/2`.

  Candidates are collected once, when the migration starts:

  * tokens which emitted the dedicated `ERC20Transfer` or `ERC721Transfer`
    events. Only ERC-404 tokens emit them, so these candidates are converted
    without further checks. Blocks with such logs that have no token transfer
    yet are added to the missing block ranges, so that they are re-fetched and
    the logs get cataloged;
  * ERC-721 (or already ERC-404) tokens which have `decimals` and ERC-20 token
    transfers, i.e. tokens emitting the standard `Transfer` event both with 3 and
    with 4 topics. That alone doesn't prove a token is ERC-404, so these
    candidates are converted only when the contract answers both
    `erc20TotalSupply()` and `erc721TotalSupply()`, see
    `Explorer.Token.MetadataRetriever.erc404_support/1`. Candidates which don't
    are logged and left untouched.

  The pending candidates are kept in the migration state, so an interrupted
  migration resumes from the token it stopped at. A token whose contract call
  failed on the node side is skipped as well: to re-run the migration, delete the
  `sanitize_erc404_tokens` record from the `migration_status` table.

  When all candidates are processed, the conversion is repeated for every
  converted token. It only touches rows which are not converted yet, so the
  repetition picks up the transfers imported while the token was being converted,
  with its old type.

  The migration is disabled by default, since ERC-404 tokens exist on a few
  chains only.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  alias Explorer.Chain.{Hash, Log, Token, TokenTransfer}
  alias Explorer.Chain.Token.Erc404
  alias Explorer.Migrator.{FillingMigration, MigrationStatus}
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever
  alias Explorer.Utility.MissingBlockRange

  @migration_name "sanitize_erc404_tokens"

  # candidates found by the dedicated ERC-404 events
  @by_events "events"
  # candidates which have to be confirmed by the contract calls
  @by_calls "calls"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"pending" => pending} = state) do
    {identifiers, rest} = Enum.split(pending, batch_size() * concurrency())

    {identifiers, %{state | "pending" => rest}}
  end

  def last_unprocessed_identifiers(state) do
    candidates = candidates()

    Logger.info("SanitizeErc404Tokens found #{Enum.count(candidates)} candidate tokens")

    state = Map.merge(state, %{"pending" => candidates, "candidates" => candidates})

    # The state is otherwise saved only after the first batch is processed. A
    # token converted in an interrupted first batch may no longer be found by the
    # candidate queries, so the whole list is saved before the conversion starts.
    MigrationStatus.update_meta(@migration_name, state)

    last_unprocessed_identifiers(state)
  end

  @impl FillingMigration
  def update_batch(identifiers) do
    Enum.count(identifiers, fn [contract_address_hash_string, source] ->
      {:ok, contract_address_hash} = Hash.Address.cast(contract_address_hash_string)

      erc404?(contract_address_hash, source) && convert(contract_address_hash, source)
    end)
  end

  defp convert(contract_address_hash, source) do
    converted_count = Erc404.convert(contract_address_hash, blocks_batch_size())
    refetched_count = if source == @by_events, do: refetch_uncataloged_blocks(contract_address_hash), else: 0

    Logger.info(
      "SanitizeErc404Tokens converted #{contract_address_hash}: " <>
        "#{converted_count} token transfers, #{refetched_count} blocks sent to re-fetch"
    )

    true
  end

  @impl FillingMigration
  def on_finish do
    candidates =
      case MigrationStatus.fetch(@migration_name) do
        %{meta: %{"candidates" => candidates}} -> candidates
        _ -> []
      end

    hashes = Enum.map(candidates, fn [contract_address_hash_string, _source] -> contract_address_hash_string end)

    Token
    |> where([t], t.contract_address_hash in ^hashes and t.type == "ERC-404")
    |> select([t], t.contract_address_hash)
    |> Repo.all(timeout: :infinity)
    |> Enum.each(&Erc404.convert(&1, blocks_batch_size()))

    :ok
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp candidates do
    by_events = tokens_by_events()
    by_events_set = MapSet.new(by_events)

    by_calls = Enum.reject(tokens_by_transfers(), &MapSet.member?(by_events_set, &1))

    Enum.map(by_events, &[to_string(&1), @by_events]) ++ Enum.map(by_calls, &[to_string(&1), @by_calls])
  end

  # The emitters of `ERC20Transfer` and `ERC721Transfer` logs, found through the
  # index on the first topic.
  defp tokens_by_events do
    emitters_query =
      from(l in Log, where: ^Log.topic_filter_dynamic(:first_topic, Erc404.dedicated_events()))
      |> Log.join_address_mapping_query()
      |> distinct(true)
      |> select([l], %{address_hash: coalesce(l.address_hash, as(:address_mapping).address_hash)})

    from(t in Token,
      join: emitter in subquery(emitters_query),
      on: emitter.address_hash == t.contract_address_hash,
      where: t.type in ["ERC-20", "ERC-721", "ERC-404"],
      order_by: t.contract_address_hash,
      select: t.contract_address_hash
    )
    |> Repo.all(timeout: :infinity)
  end

  # A contract implementing `decimals()` is rare among ERC-721 tokens, so the
  # costly check for ERC-20 transfers runs for a handful of tokens only.
  defp tokens_by_transfers do
    from(t in Token,
      as: :token,
      where: t.type in ["ERC-721", "ERC-404"] and not is_nil(t.decimals),
      where:
        exists(
          from(tt in TokenTransfer,
            where: tt.token_contract_address_hash == parent_as(:token).contract_address_hash,
            where: tt.token_type == "ERC-20"
          )
        ),
      order_by: t.contract_address_hash,
      select: t.contract_address_hash
    )
    |> Repo.all(timeout: :infinity)
  end

  defp erc404?(_contract_address_hash, @by_events), do: true

  defp erc404?(contract_address_hash, @by_calls) do
    case MetadataRetriever.erc404_support(contract_address_hash) do
      {:ok, true} ->
        true

      {:ok, false} ->
        Logger.info(
          "SanitizeErc404Tokens skipped #{contract_address_hash}: the contract doesn't implement " <>
            "erc20TotalSupply() and erc721TotalSupply()"
        )

        false

      :error ->
        Logger.warning(
          "SanitizeErc404Tokens skipped #{contract_address_hash}: failed to call erc20TotalSupply() " <>
            "and erc721TotalSupply() on the node"
        )

        false
    end
  end

  defp refetch_uncataloged_blocks(contract_address_hash) do
    contract_address_hash
    |> Erc404.uncataloged_log_block_numbers(from_block_number())
    |> Enum.chunk_every(1_000)
    |> Enum.reduce(0, fn block_numbers, acc ->
      MissingBlockRange.add_ranges_by_block_numbers(block_numbers)
      acc + Enum.count(block_numbers)
    end)
  end

  defp blocks_batch_size do
    Application.get_env(:explorer, __MODULE__)[:blocks_batch_size] || 10_000
  end

  defp from_block_number do
    Application.get_env(:explorer, __MODULE__)[:from_block] || 0
  end
end
