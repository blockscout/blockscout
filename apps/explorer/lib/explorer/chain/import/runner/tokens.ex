defmodule Explorer.Chain.Import.Runner.Tokens do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Token.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Hash, Import, Token}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Token.t()]

  @type token_holder_count_delta :: %{contract_address_hash: Hash.Address.t(), delta: neg_integer() | pos_integer()}
  @type holder_count :: non_neg_integer()
  @type token_holder_count :: %{contract_address_hash: Hash.Address.t(), count: holder_count()}

  def update_holder_counts_with_deltas(repo, token_holder_count_deltas, options) do
    parameters = token_holder_count_deltas_to_parameters(token_holder_count_deltas)

    update_holder_counts_with_parameters(repo, parameters, options)
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
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.contract_address_hash)

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
          # Don't update `contract_address_hash` as it is the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.name, EXCLUDED.symbol, EXCLUDED.total_supply, EXCLUDED.decimals, EXCLUDED.type, EXCLUDED.cataloged) IS DISTINCT FROM (?, ?, ?, ?, ?, ?)",
          token.name,
          token.symbol,
          token.total_supply,
          token.decimals,
          token.type,
          token.cataloged
        )
    )
  end

  defp token_holder_count_deltas_to_parameters(token_holder_count_deltas) when is_list(token_holder_count_deltas) do
    Enum.flat_map(token_holder_count_deltas, fn
      %{contract_address_hash: contract_address_hash, delta: delta} ->
        {:ok, contract_address_hash_bytes} = Hash.Address.dump(contract_address_hash)
        [contract_address_hash_bytes, delta]
    end)
  end

  defp update_holder_counts_with_parameters(_, [], _), do: {:ok, []}

  # sobelow_skip ["SQL.Query"]
  defp update_holder_counts_with_parameters(repo, parameters, %{timeout: timeout, timestamps: %{updated_at: updated_at}})
       when is_list(parameters) do
    update_sql = update_holder_counts_sql(parameters)

    with {:ok, %Postgrex.Result{columns: ["contract_address_hash", "holder_count"], command: :update, rows: rows}} <-
           SQL.query(repo, update_sql, [updated_at | parameters], timeout: timeout) do
      update_token_holder_counts =
        Enum.map(rows, fn [contract_address_hash_bytes, holder_count] ->
          {:ok, contract_address_hash} = Hash.Address.cast(contract_address_hash_bytes)
          %{contract_address_hash: contract_address_hash, holder_count: holder_count}
        end)

      {:ok, update_token_holder_counts}
    end
  end

  defp update_holder_counts_sql(parameters) when is_list(parameters) do
    parameters
    |> Enum.count()
    |> div(2)
    |> update_holder_counts_sql()
  end

  defp update_holder_counts_sql(row_count) when is_integer(row_count) do
    parameters_sql =
      update_holder_counts_parameters_sql(
        row_count,
        # skip $1 as it is used for the common `updated_at` timestamp
        2
      )

    """
    UPDATE tokens
    SET holder_count = holder_count + holder_counts.delta,
        updated_at = $1
    FROM (
        VALUES
          #{parameters_sql}
      ) AS holder_counts(contract_address_hash, delta)
    WHERE tokens.contract_address_hash = holder_counts.contract_address_hash AND
          holder_count IS NOT NULL
    RETURNING tokens.contract_address_hash, tokens.holder_count
    """
  end

  defp update_holder_counts_parameters_sql(row_count, start) when is_integer(row_count) do
    Enum.map_join(0..(row_count - 1), ",\n      ", fn i ->
      contract_address_hash_parameter_number = 2 * i + start
      holder_count_number = contract_address_hash_parameter_number + 1

      "($#{contract_address_hash_parameter_number}::bytea, $#{holder_count_number}::bigint)"
    end)
  end
end
