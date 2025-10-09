defmodule Explorer.Chain.Arbitrum.Reader.API.Settlement do
  @moduledoc """
    Provides API-specific functions for querying Arbitrum settlement data from the database.

    This module contains functions specifically designed for Blockscout's API endpoints
    that handle Arbitrum settlement functionality. All functions in this module enforce
    the use of replica databases for read operations by automatically passing the
    `api?: true` option to database queries.

    The module includes functions for retrieving:
    - L1 batches and their associated transactions
    - Data Availability (DA) records and blobs
    - Batch-related block information
    - Block confirmations on the parent chain
    - AnyTrust keysets

    Note: If any function from this module needs to be used outside of API handlers,
    it should be moved to `Explorer.Chain.Arbitrum.Reader.Common` with configurable
    database selection, and a wrapper function should be created in this module
    (see `highest_confirmed_block/0` as an example).
  """

  import Ecto.Query, only: [from: 2, limit: 2, order_by: 2, where: 2, where: 3]
  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Arbitrum.{
    BatchBlock,
    BatchToDaBlob,
    BatchTransaction,
    DaMultiPurposeRecord,
    L1Batch
  }

  alias Explorer.Chain.Arbitrum.Reader.Common
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.Cache.BackgroundMigrations, as: MigrationStatuses
  alias Explorer.{Chain, PagingOptions}

  @api_true [api?: true]

  @doc """
    Retrieves the total count of rollup batches indexed up to the current moment.

    This function uses an estimated count from system catalogs if available.
    If the estimate is unavailable, it performs an exact count using an aggregate query.

    ## Returns
    - The count of indexed batches.
  """
  @spec batches_count() :: non_neg_integer()
  def batches_count do
    Chain.get_table_rows_total_count(L1Batch, @api_true)
  end

  @doc """
    Fetches the most recent batch in the database.

    ## Parameters
    - `number`: must be always `:latest`

    ## Returns
    - `{:ok, Explorer.Chain.Arbitrum.L1Batch}` if the batch is found.
    - `{:error, :not_found}` if no batch exists.
  """
  @spec batch(:latest) :: {:error, :not_found} | {:ok, L1Batch.t()}
  def batch(:latest) do
    L1Batch
    |> order_by(desc: :number)
    |> limit(1)
    |> select_repo(@api_true).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @doc """
    Retrieves a specific batch by its number.

    ## Parameters
    - `number`: The specific batch number.
    - `options`: A keyword list which may contain `necessity_by_association` specifying
      the necessity for joining associations

    ## Returns
    - `{:ok, Explorer.Chain.Arbitrum.L1Batch}` if the batch is found.
    - `{:error, :not_found}` if no batch with the specified number exists.
  """
  @spec batch(binary() | non_neg_integer(), necessity_by_association: %{atom() => :optional | :required}) ::
          {:error, :not_found} | {:ok, L1Batch.t()}
  def batch(number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    L1Batch
    |> where(number: ^number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(@api_true).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @doc """
    Retrieves a list of batches from the database.

    This function constructs and executes a query to retrieve batches based on provided
    options. These options dictate not only the number of items to retrieve but also
    how many items to skip from the top. If the `committed?` option is set to true,
    it returns the ten most recent committed batches; otherwise, it fetches batches as
    dictated by other pagination parameters.

    If `batch_numbers` option is provided and not empty, the function returns only
    batches with the specified numbers, while still applying pagination.

    ## Parameters
    - `options`: A keyword list of options:
      * `necessity_by_association` - Specifies the necessity for joining associations
      * `committed?` - When true, returns only committed batches
      * `paging_options` - Specifies pagination details
      * `batch_numbers` - Optional list of specific batch numbers to retrieve

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.L1Batch` entries, filtered and ordered according to the provided options.
  """
  @spec batches(
          necessity_by_association: %{atom() => :optional | :required},
          committed?: boolean(),
          paging_options: PagingOptions.t(),
          batch_numbers: [non_neg_integer()] | nil
        ) :: [L1Batch.t()]
  def batches(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    batch_numbers = Keyword.get(options, :batch_numbers)

    base_query =
      if is_list(batch_numbers) and batch_numbers != [] do
        from(batch in L1Batch,
          where: batch.number in ^batch_numbers,
          order_by: [desc: batch.number]
        )
      else
        from(batch in L1Batch,
          order_by: [desc: batch.number]
        )
      end

    query =
      if Keyword.get(options, :committed?, false) do
        base_query
        |> Chain.join_associations(necessity_by_association)
        |> where([batch], not is_nil(batch.commitment_id) and batch.commitment_id > 0)
        |> limit(10)
      else
        paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

        base_query
        |> Chain.join_associations(necessity_by_association)
        |> page_batches(paging_options)
        |> limit(^paging_options.page_size)
      end

    select_repo(@api_true).all(query)
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(batch in query, where: batch.number < ^number)
  end

  @doc """
    Retrieves a list of rollup transactions included in a specific batch.

    ## Parameters
    - `batch_number`: The batch number whose transactions are included in L1.
    - `options`: A keyword list that is not used in this function.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.BatchTransaction` entries belonging to the specified batch.
  """
  @spec batch_transactions(non_neg_integer() | binary(), any()) :: [BatchTransaction.t()]
  def batch_transactions(batch_number, _options) do
    query = from(transaction in BatchTransaction, where: transaction.batch_number == ^batch_number)

    select_repo(@api_true).all(query)
  end

  @doc """
    Retrieves a list of rollup blocks included in a specific batch.

    This function constructs and executes a database query to retrieve a list of rollup blocks,
    considering pagination options specified in the `options` parameter. These options dictate
    the number of items to retrieve and how many items to skip from the top.

    ## Parameters
    - `batch_number`: The batch number whose transactions are included on L1.
    - `options`: A keyword list of options specifying pagination and association necessity.

    ## Returns
    - A list of `Explorer.Chain.Block` entries belonging to the specified batch.
  """
  @spec batch_blocks(non_neg_integer() | binary(),
          necessity_by_association: %{atom() => :optional | :required},
          paging_options: PagingOptions.t()
        ) :: [FullBlock.t()]
  def batch_blocks(batch_number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      from(
        fb in FullBlock,
        inner_join: rb in BatchBlock,
        on: fb.number == rb.block_number,
        select: fb,
        where: fb.consensus == true and rb.batch_number == ^batch_number
      )

    query
    |> FullBlock.block_type_filter("Block")
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(@api_true).all()
  end

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end

  @doc """
    Retrieves a Data Availability (DA) record from the database using the provided
    data key.

    Although one data blob could correspond to multiple batches, the current
    implementation returns only the first batch number that the data blob is associated
    with.

    The function supports both old and new database schemas:
    - In the old schema, batch numbers were stored directly in the arbitrum_da_multi_purpose table
    - In the new schema, batch-to-blob associations are stored in the arbitrum_batches_to_da_blobs table

    ## Parameters
    - `data_key`: The key of the data to be retrieved.

    ## Returns
    - `{:ok, {batch_number, da_info}}`, where
      - `batch_number` is the number of the batch associated with the DA record
      - `da_info` is a map containing the DA record.
    - `{:error, :not_found}` if no record with the specified `data_key` exists.
  """
  @spec get_da_record_by_data_key(binary()) :: {:ok, {non_neg_integer(), map()}} | {:error, :not_found}
  def get_da_record_by_data_key("0x" <> _ = data_key) do
    data_key_bytes = data_key |> Chain.string_to_full_hash() |> Kernel.elem(1) |> Map.get(:bytes)
    get_da_record_by_data_key(data_key_bytes)
  end

  def get_da_record_by_data_key(data_key) do
    case MigrationStatuses.get_arbitrum_da_records_normalization_finished() do
      true ->
        # Migration is complete, use new schema
        get_da_record_by_data_key_new_schema(data_key)

      _ ->
        # Migration in progress, try old schema first, then fallback to new
        case get_da_record_by_data_key_old_schema(data_key) do
          {:error, :not_found} -> get_da_record_by_data_key_new_schema(data_key)
          result -> result
        end
    end
  end

  # Builds a query to fetch DA records by data key.
  #
  # This function constructs an Ecto query to retrieve Data Availability blob
  # description (type 0) that match a specific data key.
  #
  # ## Parameters
  # - `data_key`: The key of the data to be retrieved.
  #
  # ## Returns
  # - An Ecto query that can be executed to fetch matching DA records.
  @spec build_da_records_by_data_key_query(binary()) :: Ecto.Query.t()
  defp build_da_records_by_data_key_query(data_key) do
    from(
      da_records in DaMultiPurposeRecord,
      where: da_records.data_key == ^data_key and da_records.data_type == 0
    )
  end

  # Gets DA record using the pre-migration database schema where batch numbers
  # were stored directly in the arbitrum_da_multi_purpose table.
  #
  # ## Parameters
  # - `data_key`: The key of the data to be retrieved.
  #
  # ## Returns
  # - `{:ok, {batch_number, da_info}}` if the record is found
  # - `{:error, :not_found}` if no record is found
  @spec get_da_record_by_data_key_old_schema(binary()) :: {:ok, {non_neg_integer(), map()}} | {:error, :not_found}
  defp get_da_record_by_data_key_old_schema(data_key) do
    query = build_da_records_by_data_key_query(data_key)

    case select_repo(@api_true).one(query) do
      nil -> {:error, :not_found}
      keyset -> {:ok, {keyset.batch_number, keyset.data}}
    end
  end

  # Gets DA blob description using the post-migration database schema where DA blob
  # descriptions and their associations with batches are stored in separate tables:
  #
  # - `arbitrum_da_multi_purpose` (`DaMultiPurposeRecord`): Stores the actual DA
  #   blob descriptions
  # - `arbitrum_batches_to_da_blobs` (`BatchToDaBlob`): Maps batch numbers to DA
  #   blob IDs.
  #
  # ## Parameters
  # - `data_key`: The key of the data to be retrieved.
  #
  # ## Returns
  # - `{:ok, {batch_number, da_info}}` if the pair of batch number and DA blob description is found, where:
  #   * `batch_number` is the highest batch number associated with the DA blob description
  #   * `da_info` is the data from the DA blob description
  # - `{:error, :not_found}` if no record is found
  @spec get_da_record_by_data_key_new_schema(binary()) :: {:ok, {non_neg_integer(), map()}} | {:error, :not_found}
  defp get_da_record_by_data_key_new_schema(data_key) do
    repo = select_repo(@api_true)

    with da_record when not is_nil(da_record) <- repo.one(build_da_records_by_data_key_query(data_key)),
         batch_number when not is_nil(batch_number) <-
           data_key
           |> build_batch_numbers_by_data_key_query()
           |> limit(1)
           |> repo.one() do
      {:ok, {batch_number, da_record.data}}
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
    Retrieves Data Availability (DA) information from the database using the provided
    batch number.

    The function handles both pre- and post-migration database schemas:
    - In the pre-migration schema, DA records were stored directly in the
      arbitrum_da_multi_purpose table with a batch_number field.
    - In the post-migration schema, a separate arbitrum_batches_to_da_blobs table
      enables many-to-many relationships between batches and DA blobs.

    ## Parameters
    - `batch_number`: The batch number to be used for retrieval.

    ## Returns
    - A map containing the DA information if found, otherwise an empty map.
  """
  @spec get_da_info_by_batch_number(non_neg_integer()) :: map()
  def get_da_info_by_batch_number(batch_number) do
    # The migration normalizes how Data Availability (DA) records are stored in the database.
    # Before the migration, the association between batches and DA blobs was stored directly
    # in the arbitrum_da_multi_purpose table using a batch_number field. This approach had
    # limitations when the same DA blob was used for different batches in AnyTrust chains.
    #
    # After the migration, the associations are stored in a separate arbitrum_batches_to_da_blobs
    # table, allowing many-to-many relationships between batches and DA blobs. This change
    # ensures proper handling of cases where multiple batches share the same DA blob.
    case MigrationStatuses.get_arbitrum_da_records_normalization_finished() do
      true ->
        # Migration is complete, use new schema
        get_da_info_by_batch_number_new_schema(batch_number)

      _ ->
        # Migration in progress, try old schema first, then fallback to new
        case get_da_info_by_batch_number_old_schema(batch_number) do
          %{} = empty when map_size(empty) == 0 ->
            get_da_info_by_batch_number_new_schema(batch_number)

          result ->
            result
        end
    end
  end

  # Retrieves DA info using the pre-migration database schema where DA records were stored
  # directly in the arbitrum_da_multi_purpose table with a batch_number field.
  #
  # ## Parameters
  # - `batch_number`: The batch number to lookup in the arbitrum_da_multi_purpose table
  # - `options`: A keyword list of options:
  #   - `:api?` - Whether the function is being called from an API context.
  #
  # ## Returns
  # - A map containing the DA info if found, otherwise an empty map
  @spec get_da_info_by_batch_number_old_schema(non_neg_integer()) :: map()
  defp get_da_info_by_batch_number_old_schema(batch_number) do
    query =
      from(
        da_records in DaMultiPurposeRecord,
        where: da_records.batch_number == ^batch_number and da_records.data_type == 0
      )

    case select_repo(@api_true).one(query) do
      nil -> %{}
      record -> record.data
    end
  end

  # Gets DA info using the post-migration database schema where DA records and their
  # associations with batches are stored in separate tables:
  #
  # - `arbitrum_da_multi_purpose` (`DaMultiPurposeRecord`): Stores the actual DA
  #   records with their data and type
  # - `arbitrum_batches_to_da_blobs` (`BatchToDaBlob`): Maps batch numbers to DA
  #   blob IDs.
  #
  # ## Parameters
  # - `batch_number`: The batch number to lookup in the arbitrum_batches_to_da_blobs table
  #
  # ## Returns
  # - A map containing the DA info if found, otherwise an empty map
  @spec get_da_info_by_batch_number_new_schema(non_neg_integer()) :: map()
  defp get_da_info_by_batch_number_new_schema(batch_number) do
    query =
      from(
        link in BatchToDaBlob,
        join: da_record in DaMultiPurposeRecord,
        on: link.data_blob_id == da_record.data_key,
        where: link.batch_number == ^batch_number and da_record.data_type == 0,
        select: da_record.data
      )

    case select_repo(@api_true).one(query) do
      nil -> %{}
      data -> data
    end
  end

  @doc """
    Retrieves the number of the highest confirmed rollup block.

    It calls `Common.highest_confirmed_block/1` with `@api_true` option to use
    replica database.

    ## Returns
    - The number of the highest confirmed rollup block, or `nil` if no confirmed rollup blocks are found.
  """
  @spec highest_confirmed_block() :: FullBlock.block_number() | nil
  def highest_confirmed_block do
    Common.highest_confirmed_block(@api_true)
  end

  @doc """
    Retrieves an AnyTrust keyset from the database using the provided keyset hash.

    It calls `Common.get_anytrust_keyset/1` with `api?: true` option to use
    replica database.

    ## Parameters
    - `keyset_hash`: A binary representing the hash of the keyset to be retrieved.

    ## Returns
    - A map containing information about the AnyTrust keyset, otherwise an empty map.
  """
  @spec get_anytrust_keyset(binary()) :: map()
  def get_anytrust_keyset(keyset_hash) do
    Common.get_anytrust_keyset(keyset_hash, api?: true)
  end

  @doc """
    Retrieves all batch numbers associated with a Data Availability (DA) blob hash
    and the corresponding DA blob description.

    The function handles both pre- and post-migration database schemas:
    - In the pre-migration schema, only one batch can be associated with a DA blob,
      so the function returns a single-element list with that batch number.
    - In the post-migration schema, multiple batches can share the same DA blob,
      so the function returns all associated batch numbers.

    ## Parameters
    - `data_key`: The hash of the DA blob to find associated batch numbers for.

    ## Returns
    - `{:ok, {batch_numbers, da_info}}` if the record is found, where:
      * `batch_numbers` is a list of batch numbers associated with the DA blob,
         sorted from highest to lowest
      * `da_info` is the data from the DA blob description
    - `{:error, :not_found}` if no record is found
  """
  @spec get_all_da_records_by_data_key(binary()) :: {:ok, {[non_neg_integer()], map()}} | {:error, :not_found}
  def get_all_da_records_by_data_key(data_key) do
    case MigrationStatuses.get_arbitrum_da_records_normalization_finished() do
      true ->
        repo = select_repo(@api_true)

        with da_record when not is_nil(da_record) <- repo.one(build_da_records_by_data_key_query(data_key)),
             batch_numbers when batch_numbers != [] <- repo.all(build_batch_numbers_by_data_key_query(data_key)) do
          {:ok, {batch_numbers, da_record.data}}
        else
          _ -> {:error, :not_found}
        end

      _ ->
        # During migration, fall back to getting a single batch
        case get_da_record_by_data_key(data_key) do
          {:ok, {batch_number, da_info}} -> {:ok, {[batch_number], da_info}}
          {:error, :not_found} = error -> error
        end
    end
  end

  # Builds a query to fetch batch numbers associated with a DA blob hash.
  #
  # This function constructs an Ecto query to retrieve batch numbers from the
  # arbitrum_batches_to_da_blobs table that match a specific data blob ID (hash).
  # The batch numbers are sorted in descending order.
  #
  # ## Parameters
  # - `data_key`: The hash of the data blob to find associated batch numbers for.
  #
  # ## Returns
  # - An Ecto query that can be executed to fetch matching batch numbers.
  @spec build_batch_numbers_by_data_key_query(binary()) :: Ecto.Query.t()
  defp build_batch_numbers_by_data_key_query(data_key) do
    from(
      link in BatchToDaBlob,
      where: link.data_blob_id == ^data_key,
      select: link.batch_number,
      order_by: [desc: link.batch_number]
    )
  end
end
