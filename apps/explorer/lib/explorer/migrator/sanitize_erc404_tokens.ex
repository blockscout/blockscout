# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeErc404Tokens do
  @moduledoc """
  Finds ERC-404 tokens which were indexed as ERC-721 or ERC-20 ones and converts
  their stored data with `Explorer.Chain.Token.Erc404.convert/2`.

  The candidates are:

  * tokens which emitted the dedicated `ERC20Transfer` or `ERC721Transfer`
    events. Only ERC-404 tokens emit them, so these candidates are converted
    without further checks. Blocks with such logs that have no token transfer
    yet are added to the missing block ranges, so that they are re-fetched and
    the logs get cataloged;
  * ERC-721 tokens which have `decimals`, which an ordinary ERC-721 contract
    doesn't implement. These candidates are converted only when the contract
    answers both `erc20TotalSupply()` and `erc721TotalSupply()`, see
    `Explorer.Token.MetadataRetriever.erc404_support/1`. Candidates which don't
    are logged and left untouched. The tokens of this kind which were already
    retyped to ERC-404 are candidates as well, so that an interrupted conversion
    is completed, see `Explorer.Chain.Token.Erc404.conversion_pending?/1`.

  The candidates are found again whenever the migration starts, in the same
  order, and the migration state keeps the last processed one, so an
  interrupted migration resumes from the token it stopped at. A token whose
  contract calls kept failing on the node side is skipped: to re-run the
  migration, delete the `sanitize_erc404_tokens` record from the
  `migration_status` table.

  The transfers and balances imported while a token is being converted get the
  ERC-404 shape on import, see
  `Explorer.Chain.Token.Erc404.normalize_imported_token_transfers/2`, so the
  conversion needs no second pass.

  The migration is disabled by default, since ERC-404 tokens exist on a few
  chains only.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  alias Explorer.Chain.{Hash, Log, Token}
  alias Explorer.Chain.Token.Erc404
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever
  alias Explorer.Utility.MissingBlockRange

  @migration_name "sanitize_erc404_tokens"

  # candidates found by the dedicated ERC-404 events
  @by_events "events"
  # candidates which have to be confirmed by the contract calls
  @by_calls "calls"

  # the process dictionary key of the candidates found on start
  @candidates_key :sanitize_erc404_tokens_candidates

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  # The candidate list is kept in memory rather than in the migration state,
  # which is saved after every batch: the state keeps the last processed
  # candidate only.
  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    cursor = state["last_processed"]

    {identifiers, _rest} =
      candidates()
      |> Enum.drop_while(&(not is_nil(cursor) and order_key(&1) <= order_key(cursor)))
      |> Enum.split(batch_size() * concurrency())

    case List.last(identifiers) do
      nil -> {[], state}
      last_identifier -> {identifiers, Map.put(state, "last_processed", last_identifier)}
    end
  end

  @impl FillingMigration
  def update_batch(identifiers) do
    Enum.count(identifiers, fn [contract_address_hash_string, source] ->
      {:ok, contract_address_hash} = Hash.Address.cast(contract_address_hash_string)

      to_convert?(contract_address_hash, source) && convert(contract_address_hash, source)
    end)
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp convert(contract_address_hash, source) do
    converted_count = Erc404.convert(contract_address_hash, rows_batch_size())
    refetched_count = if source == @by_events, do: refetch_uncataloged_blocks(contract_address_hash), else: 0

    Logger.info(
      "SanitizeErc404Tokens converted #{contract_address_hash}: " <>
        "#{converted_count} token transfers, #{refetched_count} blocks sent to re-fetch"
    )

    true
  end

  defp candidates do
    case Process.get(@candidates_key) do
      nil ->
        candidates = find_candidates()
        Logger.info("SanitizeErc404Tokens found #{Enum.count(candidates)} candidate tokens")
        Process.put(@candidates_key, candidates)
        candidates

      candidates ->
        candidates
    end
  end

  # The candidates found by the events go first, each group is ordered by the
  # token address. The lowercase hex strings sort the same way as the addresses.
  defp order_key([contract_address_hash_string, @by_events]), do: {0, contract_address_hash_string}
  defp order_key([contract_address_hash_string, @by_calls]), do: {1, contract_address_hash_string}

  defp find_candidates do
    by_events = tokens_by_events()
    by_events_set = MapSet.new(by_events)

    by_calls = Enum.reject(tokens_with_decimals(), &MapSet.member?(by_events_set, &1))

    Enum.map(by_events, &[to_string(&1), @by_events]) ++ Enum.map(by_calls, &[to_string(&1), @by_calls])
  end

  # The emitters of `ERC20Transfer` and `ERC721Transfer` logs, found through the
  # index on the first topic.
  defp tokens_by_events do
    emitters_query =
      from(l in Log, where: ^Log.topic_filter_dynamic(:first_topic, Erc404.dedicated_events()))
      |> Log.join_address_mapping_query()
      |> distinct(true)
      |> select(%{address_hash: as(:address_mapping).address_hash})

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
  # contract calls are made for a handful of tokens only. Their transfers are not
  # looked at: no index tells the ERC-20 transfers of a token apart.
  defp tokens_with_decimals do
    from(t in Token,
      where: t.type in ["ERC-721", "ERC-404"] and not is_nil(t.decimals),
      order_by: t.contract_address_hash,
      select: t.contract_address_hash
    )
    |> Repo.all(timeout: :infinity)
  end

  defp to_convert?(_contract_address_hash, @by_events), do: true

  defp to_convert?(contract_address_hash, @by_calls) do
    case Repo.get_by(Token, contract_address_hash: contract_address_hash) do
      %Token{type: "ERC-404"} -> Erc404.conversion_pending?(contract_address_hash)
      %Token{type: "ERC-721"} -> erc404?(contract_address_hash)
      _ -> false
    end
  end

  defp erc404?(contract_address_hash) do
    case MetadataRetriever.erc404_support(contract_address_hash, erc404_calls_attempts()) do
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

  defp erc404_calls_attempts do
    max(Application.get_env(:explorer, :token_functions_reader_max_retries) || 1, 1)
  end

  defp rows_batch_size do
    Application.get_env(:explorer, __MODULE__)[:rows_batch_size] || 1_000
  end

  defp from_block_number do
    Application.get_env(:explorer, __MODULE__)[:from_block] || 0
  end
end
