defmodule Indexer.Fetcher.Arbitrum.DA.Common do
  @moduledoc """
    TBD
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]

  alias Indexer.Fetcher.Arbitrum.DA.{Anytrust, Celestia}

  # Distinguishes between different types of data availability information and parses it.
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

  # Parses data availability information from a given binary input based on the header flag.
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
        log_error("DAS messages are not supported.")
        {:error, nil, nil}

      136 ->
        Anytrust.parse_batch_accompanying_data(batch_number, rest)

      _ ->
        log_error("Unknown header flag found during an attempt to parse DA data: #{header_flag}")
        {:error, nil, nil}
    end
  end

  @spec prepare_for_import([Celestia.t() | Anytrust.t() | map()], %{
          :sequencer_inbox_address => String.t(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
        }) :: [%{:data_type => non_neg_integer(), :data_key => binary(), :data => map(), :batch_number => non_neg_integer() | nil}]
  def prepare_for_import([], _), do: []

  def prepare_for_import(da_info, l1_connection_config) do
    da_info
    |> Enum.reduce({[], %{}}, fn info, {acc, cache} ->
      case info do
        %Celestia{} ->
          {Celestia.prepare_for_import(acc, info), cache}

        %Anytrust{} ->
          Anytrust.prepare_for_import(acc, info, l1_connection_config, cache)

        _ ->
          {acc, cache}
      end
    end)
    |> Kernel.elem(0)
  end

  @spec required_import?(:in_blob4844 | :in_calldata | :in_celestia | :in_anytrust | nil) :: boolean()
  def required_import?(da_type) do
    da_type in [:in_celestia, :in_anytrust]
  end
end
