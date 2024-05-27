defmodule Indexer.Fetcher.Arbitrum.DA.Anytrust do
  @moduledoc """
    TBD
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1, log_info: 1, log_debug: 1]

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Helper, as: IndexerHelper

  @enforce_keys [
    :batch_number,
    :keyset_hash,
    :data_hash,
    :timeout,
    :signers_mask,
    :bls_signature
  ]
  defstruct @enforce_keys

  @typedoc """
  AnyTrust DA info struct:
    * `batch_number` - The batch number in Arbitrum rollup associated with the Celestia data.
    * `keyset_hash` - Hash of the keyset used to sign the data.
    * `data_hash` - Hash of the data.
    * `timeout` - Timeout for the data.
    * `signers_mask` - Mask of signers.
    * `bls_signature` - Aggregated BLS signature.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          keyset_hash: binary(),
          data_hash: binary(),
          timeout: DateTime.t(),
          signers_mask: non_neg_integer(),
          bls_signature: binary()
        }

  # keccak256("SetValidKeyset(bytes32,bytes)")
  @set_valid_keyset_event "0xabca9b7986bc22ad0160eb0cb88ae75411eacfba4052af0b457a9335ef655722"
  @set_valid_keyset_event_unindexed_params [:bytes]

  # Parses Anytrust data from a given binary input, representing a data availability certificate.
  #
  # ## Parameters
  # - `batch_number`: The batch number in Arbitrum rollup associated with the Celestia data.
  # - A binary input representing the data availability certificate.
  #
  # ## Returns
  # - `{:ok, :in_anytrust, anytrust_da_info}` on successful parsing.
  # - `{:error, nil, nil}` if the input cannot be parsed.
  @spec parse_batch_accompanying_data(non_neg_integer(), binary()) :: {:ok, :in_anytrust, t()} | {:error, nil, nil}
  def parse_batch_accompanying_data(batch_number, <<
        keyset_hash::binary-size(32),
        data_hash::binary-size(32),
        timeout::big-unsigned-integer-size(64),
        _version::size(8),
        signers_mask::big-unsigned-integer-size(64),
        bls_signature::binary-size(96)
      >>) do
    # https://github.com/OffchainLabs/nitro/blob/ad9ab00723e13cf98307b9b65774ad455594ef7b/arbstate/das_reader.go#L95-L151
    {:ok, :in_anytrust,
     %__MODULE__{
       batch_number: batch_number,
       keyset_hash: keyset_hash,
       data_hash: data_hash,
       timeout: IndexerHelper.timestamp_to_datetime(timeout),
       signers_mask: signers_mask,
       bls_signature: bls_signature
     }}
  end

  def parse_batch_accompanying_data(_, _) do
    log_error("Can not parse Anytrust DA message.")
    {:error, nil, nil}
  end

  @spec prepare_for_import(
          list(),
          t(),
          %{
            :sequencer_inbox_address => String.t(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
          },
          %{binary() => boolean()}
        ) ::
          {[
             %{
               :data_type => non_neg_integer(),
               :data_key => binary(),
               :data => %{
                 :keyset_hash => String.t(),
                 :data_hash => String.t(),
                 :timeout => DateTime.t(),
                 :signers_mask => non_neg_integer(),
                 :bls_signature => String.t()
               },
               :batch_number => non_neg_integer() | nil
             }
           ], %{binary() => boolean()}}
  def prepare_for_import(source, %__MODULE__{} = da_info, l1_connection_config, cache) do
    data = %{
      keyset_hash: ArbitrumHelper.bytes_to_hex_str(da_info.keyset_hash),
      data_hash: ArbitrumHelper.bytes_to_hex_str(da_info.data_hash),
      timeout: da_info.timeout,
      signers_mask: da_info.signers_mask,
      bls_signature: ArbitrumHelper.bytes_to_hex_str(da_info.bls_signature)
    }

    res = [
      %{
        data_type: 0,
        data_key: da_info.data_hash,
        data: data,
        batch_number: da_info.batch_number
      }
    ]

    {check_result, keyset_map, updated_cache} = check_if_new_keyset(da_info.keyset_hash, l1_connection_config, cache)

    updated_res =
      case check_result do
        :new_keyset ->
          [
            %{
              data_type: 1,
              data_key: da_info.keyset_hash,
              data: keyset_map,
              batch_number: nil
            }
            | res
          ]

        _ ->
          res
      end

    {updated_res ++ source, updated_cache}
  end

  defp check_if_new_keyset(keyset_hash, _, cache) when is_map_key(cache, keyset_hash) do
    {:existing_keyset, nil, cache}
  end

  defp check_if_new_keyset(keyset_hash, l1_connection_config, cache) do
    updated_cache = Map.put_new(cache, keyset_hash, true)

    case Db.anytrust_keyset_exists?(keyset_hash) do
      true ->
        log_info("Keyset #{keyset_hash} already exists in the database")
        {:existing_keyset, nil, updated_cache}

      false ->
        {:new_keyset, get_keyset_info_from_l1(keyset_hash, l1_connection_config), updated_cache}
    end
  end

  defp get_keyset_info_from_l1(keyset_hash, %{
         sequencer_inbox_address: sequencer_inbox_address,
         json_rpc_named_arguments: json_rpc_named_arguments
       }) do
    keyset_applied_block_number =
      Rpc.get_block_number_for_keyset(sequencer_inbox_address, keyset_hash, json_rpc_named_arguments)

    log_debug("Keyset applied block number: #{keyset_applied_block_number}")

    raw_keyset_data =
      get_keyset_raw_data(keyset_hash, keyset_applied_block_number, sequencer_inbox_address, json_rpc_named_arguments)

    decode_keyset(raw_keyset_data)

    # %{block_number: keyset_applied_block_number}
  end

  defp get_keyset_raw_data(keyset_hash, block_number, sequencer_inbox_address, json_rpc_named_arguments) do
    {:ok, logs} =
      IndexerHelper.get_logs(
        block_number,
        block_number,
        sequencer_inbox_address,
        [@set_valid_keyset_event, ArbitrumHelper.bytes_to_hex_str(keyset_hash)],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      log_info("Found #{length(logs)} SetValidKeyset logs")

      set_valid_keyset_event_parse(List.first(logs))
    else
      log_error("No SetValidKeyset logs found in the block #{block_number}")
      nil
    end
  end

  defp set_valid_keyset_event_parse(event) do
    [keyset_data] = decode_data(event["data"], @set_valid_keyset_event_unindexed_params)

    keyset_data
  end

  # https://github.com/OffchainLabs/nitro/blob/ad9ab00723e13cf98307b9b65774ad455594ef7b/arbstate/das_reader.go#L217-L248
  defp decode_keyset(<<
         assumed_honest::big-unsigned-integer-size(64),
         num_keys::big-unsigned-integer-size(64),
         rest::binary
       >>)
       when num_keys <= 64 do
    {pubkeys, _} = decode_pubkeys(rest, num_keys, [])

    %{
      assumed_honest: assumed_honest,
      pubkeys: pubkeys
    }
  end

  defp decode_pubkeys(<<>>, 0, acc), do: {Enum.reverse(acc), <<>>}
  defp decode_pubkeys(<<>>, _num_keys, _acc), do: {:error, "Insufficient data to decode public keys"}

  defp decode_pubkeys(data, num_keys, acc) when num_keys > 0 do
    <<high_byte, low_byte, rest::binary>> = data
    pubkey_len = high_byte * 256 + low_byte

    <<pubkey_data::binary-size(pubkey_len), remaining::binary>> = rest
    pubkey = parse_pubkey(pubkey_data)
    decode_pubkeys(remaining, num_keys - 1, [pubkey | acc])
  end

  # https://github.com/OffchainLabs/nitro/blob/35bd2aa59611702e6403051af581fddda7c17f74/blsSignatures/blsSignatures.go#L206C6-L242
  defp parse_pubkey(<<proof_len::size(8), rest::binary>>) do
    if proof_len == 0 do
      # Trusted source, no proof bytes, the rest is the key
      %{trusted: true, key: ArbitrumHelper.bytes_to_hex_str(rest)}
    else
      <<proof_bytes::binary-size(proof_len), key_bytes::binary>> = rest

      %{
        trusted: false,
        proof: ArbitrumHelper.bytes_to_hex_str(proof_bytes),
        key: ArbitrumHelper.bytes_to_hex_str(key_bytes)
      }
    end
  end
end
