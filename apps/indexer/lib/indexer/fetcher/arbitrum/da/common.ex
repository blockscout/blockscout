defmodule Indexer.Fetcher.Arbitrum.DA.Common do
  @moduledoc """
    This module provides common functionalities for handling data availability (DA)
    information in the Arbitrum rollup.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]

  alias Indexer.Fetcher.Arbitrum.DA.{Anytrust, Celestia}
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: Db

  alias Explorer.Chain.Arbitrum

  @doc """
    Examines the batch accompanying data to determine its type and parse it accordingly.

    This function examines the batch accompanying data to identify its type and then
    parses it based on the identified type if necessary.

    ## Parameters
    - `batch_number`: The batch number in the Arbitrum rollup.
    - `batch_accompanying_data`: The binary data accompanying the batch.

    ## Returns
    - `{status, da_type, da_info}` where `da_type` is one of `:in_blob4844`,
      `:in_calldata`, `:in_celestia`, `:in_anytrust`, or `nil` if the accompanying
      data cannot be parsed or is of an unsupported type. `da_info` contains the DA
      info descriptor for Celestia or Anytrust.
  """
  @spec examine_batch_accompanying_data(non_neg_integer(), binary()) ::
          {:ok, :in_blob4844, nil}
          | {:ok, :in_calldata, nil}
          | {:ok, :in_celestia, Celestia.t()}
          | {:ok, :in_anytrust, Anytrust.t()}
          | {:error, nil, nil}
  def examine_batch_accompanying_data(batch_number, batch_accompanying_data) do
    case batch_accompanying_data do
      nil -> {:ok, :in_blob4844, nil}
      _ -> parse_data_availability_info(batch_number, batch_accompanying_data)
    end
  end

  @doc """
    Prepares data availability (DA) information for import.

    This function processes a list of DA information, either from Celestia or Anytrust,
    preparing it for database import. It handles deduplication of records within the same
    processing chunk and against existing database records.

    ## Parameters
    - `da_info`: A list of DA information structs.
    - `l1_connection_config`: A map containing the address of the Sequencer Inbox contract
      and configuration parameters for the JSON RPC connection.

    ## Returns
    - A tuple containing:
      - A list of DA records (`DaMultiPurposeRecord`) ready for import, deduplicated both within
        the current batch and against existing database records.
      - A list of batch-to-blob associations (`BatchToDaBlob`) ready for import.
  """
  @spec prepare_for_import([Celestia.t() | Anytrust.t() | map()], %{
          :sequencer_inbox_address => String.t(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
        }) :: {[Arbitrum.DaMultiPurposeRecord.to_import()], [Arbitrum.BatchToDaBlob.to_import()]}
  def prepare_for_import([], _), do: {[], []}

  def prepare_for_import(da_info, l1_connection_config) do
    # Initialize accumulator with maps for each DA type
    initial_acc = {
      %{
        celestia: %{},
        anytrust: %{}
      },
      [],
      MapSet.new()
    }

    # Process all DA info entries
    {da_records_by_type, batch_to_blobs, _cache} =
      da_info
      |> Enum.reduce(initial_acc, fn info, {da_records_by_type, batch_to_blob_acc, cache} ->
        case info do
          %Celestia{} ->
            {updated_records, updated_batches} =
              Celestia.prepare_for_import({da_records_by_type.celestia, batch_to_blob_acc}, info)

            {
              %{da_records_by_type | celestia: updated_records},
              updated_batches,
              cache
            }

          %Anytrust{} ->
            {{updated_records, updated_batches}, updated_cache} =
              Anytrust.prepare_for_import(
                {da_records_by_type.anytrust, batch_to_blob_acc},
                info,
                l1_connection_config,
                cache
              )

            {
              %{da_records_by_type | anytrust: updated_records},
              updated_batches,
              updated_cache
            }

          _ ->
            {da_records_by_type, batch_to_blob_acc, cache}
        end
      end)

    # Eliminate conflicts with database records
    da_records = eliminate_conflicts(da_records_by_type)

    {da_records, batch_to_blobs}
  end

  # Eliminates conflicts between candidate DA records and existing database records.
  #
  # This function checks for conflicts between candidate records and existing database
  # records, and resolves them according to type-specific rules.
  #
  # ## Parameters
  # - `da_records_by_type`: A map containing candidate records organized by DA type
  #   (`:celestia` and `:anytrust`), where each type has a map of records keyed by `data_key`.
  #
  # ## Returns
  # - A list of `DaMultiPurposeRecord` records after conflict resolution, ready for import.
  @spec eliminate_conflicts(%{
          celestia: %{binary() => Arbitrum.DaMultiPurposeRecord.to_import()},
          anytrust: %{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}
        }) :: [Arbitrum.DaMultiPurposeRecord.to_import()]
  defp eliminate_conflicts(da_records_by_type) do
    # Define the types and their corresponding resolution modules
    type_configs = [
      {:celestia, da_records_by_type.celestia, &Celestia.resolve_conflict/2},
      {:anytrust, da_records_by_type.anytrust, &Anytrust.resolve_conflict/2}
    ]

    # Process each type using the same pattern
    type_configs
    |> Enum.flat_map(fn {_type, records_map, resolve_fn} ->
      process_records(records_map, resolve_fn)
    end)
  end

  # Processes candidate DA records using a type-specific resolution function.
  #
  # This function takes a map of candidate DA records and a resolution function specific
  # to the DA type (Celestia or AnyTrust). It fetches any existing records from the
  # database with matching data keys and uses the resolution function to determine
  # which records should be imported.
  #
  # ## Parameters
  # - `records_map`: A map where data keys map to candidate DA records to be imported
  # - `resolve_fn`: A function that resolves conflicts between database records and
  #   candidate records according to type-specific rules
  #
  # ## Returns
  # - A list of DA records that should be imported after conflict resolution
  @spec process_records(
          %{binary() => Arbitrum.DaMultiPurposeRecord.to_import()},
          ([Explorer.Chain.Arbitrum.DaMultiPurposeRecord.t()],
           %{binary() => Explorer.Chain.Arbitrum.DaMultiPurposeRecord.to_import()} ->
             [Arbitrum.DaMultiPurposeRecord.to_import()])
        ) :: [Arbitrum.DaMultiPurposeRecord.to_import()]
  defp process_records(records_map, resolve_fn)

  defp process_records(records_map, _resolve_fn) when map_size(records_map) == 0, do: []

  defp process_records(records_map, resolve_fn) do
    # Get all keys from the records map
    keys = Map.keys(records_map)

    # Fetch existing records from DB with these keys
    db_records = Db.da_records_by_keys(keys)

    # Call the resolution function with db_records and candidate records
    resolve_fn.(db_records, records_map)
  end

  @doc """
    Determines if data availability information requires import.

    This function checks the type of data availability (DA) and returns whether
    the data should be imported based on its type.

    ## Parameters
    - `da_type`: The type of data availability, which can be `:in_blob4844`, `:in_calldata`,
      `:in_celestia`, `:in_anytrust`, or `nil`.

    ## Returns
    - `true` if the DA type is `:in_celestia` or `:in_anytrust`, indicating that the data
      requires import.
    - `false` for all other DA types, indicating that the data does not require import.
  """
  @spec required_import?(:in_blob4844 | :in_calldata | :in_celestia | :in_anytrust | nil) :: boolean()
  def required_import?(da_type) do
    da_type in [:in_celestia, :in_anytrust]
  end

  # Parses data availability information based on the header flag.
  @spec parse_data_availability_info(non_neg_integer(), binary()) ::
          {:ok, :in_calldata, nil}
          | {:ok, :in_celestia, Celestia.t()}
          | {:ok, :in_anytrust, Anytrust.t()}
          | {:error, nil, nil}
  defp parse_data_availability_info(batch_number, <<
         header_flag::size(8),
         rest::binary
       >>) do
    # https://github.com/OffchainLabs/nitro-contracts/blob/90037b996509312ef1addb3f9352457b8a99d6a6/src/bridge/SequencerInbox.sol#L69-L81
    case header_flag do
      0 ->
        {:ok, :in_calldata, nil}

      32 ->
        log_error("ZERO HEAVY messages are not supported.")
        {:error, nil, nil}

      99 ->
        Celestia.parse_batch_accompanying_data(batch_number, rest)

      128 ->
        Anytrust.parse_batch_accompanying_data(batch_number, rest)

      136 ->
        Anytrust.parse_batch_accompanying_data(batch_number, rest)

      _ ->
        log_error("Unknown header flag found during an attempt to parse DA data: #{header_flag}")
        {:error, nil, nil}
    end
  end

  defp parse_data_availability_info(_, _) do
    log_error("Failed to parse data availability information.")
    {:error, nil, nil}
  end
end
