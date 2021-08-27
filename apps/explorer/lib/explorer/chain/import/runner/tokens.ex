defmodule Explorer.Chain.Import.Runner.Tokens do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Token.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Hash, Import, Token}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Token.t()]

  @type token_holder_count_delta :: %{contract_address_hash: Hash.Address.t(), delta: neg_integer() | pos_integer()}
  @type holder_count :: non_neg_integer()
  @type token_holder_count :: %{contract_address_hash: Hash.Address.t(), count: holder_count()}

  def acquire_contract_address_tokens(repo, contract_address_hashes) do
    token_query =
      from(
        token in Token,
        where: token.contract_address_hash in ^contract_address_hashes,
        # Enforce Token ShareLocks order (see docs: sharelocks.md)
        order_by: token.contract_address_hash,
        lock: "FOR UPDATE"
      )

    tokens = repo.all(token_query)

    {:ok, tokens}
  end

  def update_holder_counts_with_deltas(repo, token_holder_count_deltas, %{
        timeout: timeout,
        timestamps: %{updated_at: updated_at}
      }) do
    # NOTE that acquire_contract_address_tokens needs to be called before this
    {hashes, deltas} =
      token_holder_count_deltas
      |> Enum.map(fn %{contract_address_hash: contract_address_hash, delta: delta} ->
        {:ok, contract_address_hash_bytes} = Hash.Address.dump(contract_address_hash)
        {contract_address_hash_bytes, delta}
      end)
      |> Enum.unzip()

    query =
      from(
        token in Token,
        join:
          deltas in fragment(
            "(SELECT unnest(?::bytea[]) as contract_address_hash, unnest(?::bigint[]) as delta)",
            ^hashes,
            ^deltas
          ),
        on: token.contract_address_hash == deltas.contract_address_hash,
        where: not is_nil(token.holder_count),
        # ShareLocks order already enforced by `acquire_contract_address_tokens` (see docs: sharelocks.md)
        update: [
          set: [
            holder_count: token.holder_count + deltas.delta,
            updated_at: ^updated_at
          ]
        ],
        select: %{
          contract_address_hash: token.contract_address_hash,
          holder_count: token.holder_count
        }
      )

    {_total, result} = repo.update_all(query, [], timeout: timeout)

    {:ok, result}
  end

  @impl Import.Runner
  def ecto_schema_module, do: Token

  @impl Import.Runner
  def option_key, do: :tokens

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :tokens, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          required(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Token.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    ordered_changes_list =
      changes_list
      # brand new tokens start with no holders
      |> Stream.map(&Map.put_new(&1, :holder_count, 0))
      # Enforce Token ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(& &1.contract_address_hash)

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: :contract_address_hash,
        on_conflict: on_conflict,
        for: Token,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  def default_on_conflict do
    from(
      token in Token,
      update: [
        set: [
          name: fragment("EXCLUDED.name"),
          symbol: fragment("EXCLUDED.symbol"),
          total_supply: fragment("EXCLUDED.total_supply"),
          decimals: fragment("EXCLUDED.decimals"),
          type: fragment("EXCLUDED.type"),
          cataloged: fragment("EXCLUDED.cataloged"),
          bridged: fragment("EXCLUDED.bridged"),
          skip_metadata: fragment("EXCLUDED.skip_metadata"),
          # `holder_count` is not updated as a pre-existing token means the `holder_count` is already initialized OR
          #   need to be migrated with `priv/repo/migrations/scripts/update_new_tokens_holder_count_in_batches.sql.exs`
          # Don't update `contract_address_hash` as it is the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.symbol, EXCLUDED.total_supply, EXCLUDED.decimals, EXCLUDED.type, EXCLUDED.cataloged, EXCLUDED.bridged, EXCLUDED.skip_metadata) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?)",
          token.name,
          token.symbol,
          token.total_supply,
          token.decimals,
          token.type,
          token.cataloged,
          token.bridged,
          token.skip_metadata
        )
    )
  end
end
