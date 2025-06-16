defmodule Explorer.Migrator.ReindexBlocksWithMissingTransactions do
  @moduledoc """
  Searches for all blocks where the number of transactions differs from the number of transactions on the node,
  and sets refetch_needed=true for them.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Migrator.{FillingMigration, MigrationStatus}

  @migration_name "reindex_blocks_with_missing_transactions"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(%{"max_block_number" => from_block_number} = state) do
    limit = batch_size() * concurrency()
    to_block_number = max(from_block_number - limit + 1, 0)

    {Enum.to_list(from_block_number..to_block_number), %{state | "max_block_number" => to_block_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    state
    |> Map.put("max_block_number", BlockNumber.get_max())
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    Block
    |> where([b], b.number in ^block_numbers)
    |> where([b], b.consensus == true)
    |> where([b], b.refetch_needed == false)
    |> select([b], b.number)
    |> Repo.all()
    |> do_update()
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp do_update([]), do: :ok

  defp do_update(consensus_block_numbers) do
    db_transactions_count_map =
      Transaction
      |> where([t], t.block_number in ^consensus_block_numbers)
      |> group_by([t], t.block_number)
      |> select([t], {t.block_number, count("*")})
      |> Repo.all()
      |> Map.new()

    case fetch_transactions_count(consensus_block_numbers) do
      {:ok, %{transactions_count_map: node_transactions_count_map, errors: errors}} ->
        unless Enum.empty?(errors) do
          Logger.warning("Migration #{@migration_name} encountered errors fetching blocks: #{inspect(errors)}")
        end

        consensus_block_numbers
        |> Enum.filter(&Map.has_key?(node_transactions_count_map, &1))
        |> Enum.reject(fn number -> db_transactions_count_map[number] == node_transactions_count_map[number] end)
        |> Block.set_refetch_needed()

      error ->
        Logger.error("Migration #{@migration_name} failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_transactions_count(block_numbers) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    id_to_params = EthereumJSONRPC.id_to_params(block_numbers)

    id_to_params
    |> Enum.map(fn {id, number} ->
      EthereumJSONRPC.request(%{
        id: id,
        method: "eth_getBlockTransactionCountByNumber",
        params: [EthereumJSONRPC.integer_to_quantity(number)]
      })
    end)
    |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)
    |> case do
      {:ok, responses} ->
        %{errors: errors, counts: counts} =
          responses
          |> EthereumJSONRPC.sanitize_responses(id_to_params)
          |> Enum.reduce(%{errors: [], counts: %{}}, fn
            %{id: id, result: nil}, %{errors: errors} = acc ->
              error = {:error, %{code: 404, message: "Not Found", data: Map.fetch!(id_to_params, id)}}
              %{acc | errors: [error | errors]}

            %{id: id, result: count}, %{counts: counts} = acc ->
              %{acc | counts: Map.put(counts, Map.fetch!(id_to_params, id), EthereumJSONRPC.quantity_to_integer(count))}

            %{id: id, error: error}, %{errors: errors} = acc ->
              %{acc | errors: [{:error, Map.put(error, :data, Map.fetch!(id_to_params, id))} | errors]}
          end)

        {:ok, %{transactions_count_map: Map.new(counts), errors: errors}}

      error ->
        error
    end
  end
end
