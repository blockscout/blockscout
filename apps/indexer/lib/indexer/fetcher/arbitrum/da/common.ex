defmodule Indexer.Fetcher.Arbitrum.DA.Common do
  @moduledoc """
    This module provides common functionalities for handling data availability (DA)
    information in the Arbitrum rollup.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]

  alias Indexer.Fetcher.Arbitrum.DA.{Anytrust, Celestia}

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
    preparing it for database import.

    ## Parameters
    - `da_info`: A list of DA information structs.
    - `l1_connection_config`: A map containing the address of the Sequencer Inbox contract
      and configuration parameters for the JSON RPC connection.

    ## Returns
    - A tuple containing:
      - A list of DA records (`DaMultiPurposeRecord`) ready for import, each containing:
        - `:data_key`: A binary key identifying the data.
        - `:data_type`: An integer indicating the type of data, which can be `0`
          for data blob descriptors and `1` for Anytrust keyset descriptors.
        - `:data`: A map containing the DA information.
        - `:batch_number`: The batch number associated with the data, or `nil`.
      - A list of batch-to-blob associations (`BatchToDaBlob`) ready for import.
  """
  @spec prepare_for_import([Celestia.t() | Anytrust.t() | map()], %{
          :sequencer_inbox_address => String.t(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
        }) :: {[Arbitrum.DaMultiPurposeRecord.to_import()], [Arbitrum.BatchToDaBlob.to_import()]}
  def prepare_for_import([], _), do: {[], []}

  def prepare_for_import(da_info, l1_connection_config) do
    da_info
    |> Enum.reduce({{[], []}, MapSet.new()}, fn info, {{da_records_acc, batch_to_blob_acc}, cache} ->
      case info do
        %Celestia{} ->
          {da_records, batch_to_blobs} = Celestia.prepare_for_import({da_records_acc, batch_to_blob_acc}, info)
          {{da_records, batch_to_blobs}, cache}

        %Anytrust{} ->
          {{da_records, batch_to_blobs}, updated_cache} =
            Anytrust.prepare_for_import({da_records_acc, batch_to_blob_acc}, info, l1_connection_config, cache)

          {{da_records, batch_to_blobs}, updated_cache}

        _ ->
          {{da_records_acc, batch_to_blob_acc}, cache}
      end
    end)
    |> then(fn {{da_records, batch_to_blobs}, _cache} -> {da_records, batch_to_blobs} end)
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

      12 ->
        Celestia.parse_batch_accompanying_data(batch_number, rest)

      32 ->
        log_error("ZERO HEAVY messages are not supported.")
        {:error, nil, nil}

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
