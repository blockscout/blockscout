defmodule Indexer.Fetcher.Arbitrum.DA.Anytrust do
  @moduledoc """
    Provides functionality for handling AnyTrust data availability information
    within the Arbitrum rollup context.
  """

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1, log_info: 1, log_debug: 1]

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: Db
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain.Arbitrum

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
    * `batch_number` - The batch number in the Arbitrum rollup associated with the
                       AnyTrust data blob.
    * `keyset_hash` - The hash identifying a keyset that defines the rules (threshold
                      and committee members) to issue the DA certificate.
    * `data_hash` - The hash of the data blob stored by the AnyTrust committee.
    * `timeout` - Expiration timeout for the data blob.
    * `signers_mask` - Mask identifying committee members who guaranteed data availability.
    * `bls_signature` - Aggregated BLS signature of the committee members.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          keyset_hash: binary(),
          data_hash: binary(),
          timeout: DateTime.t(),
          signers_mask: non_neg_integer(),
          bls_signature: binary()
        }

  @typedoc """
  AnyTrust DA certificate struct:
    * `keyset_hash` - The hash identifying a keyset that defines the rules (threshold
                      and committee members) to issue the DA certificate.
    * `data_hash` - The hash of the data blob stored by the AnyTrust committee.
    * `timeout` - Expiration timeout for the data blob.
    * `signers_mask` - Mask identifying committee members who guaranteed data availability.
    * `bls_signature` - Aggregated BLS signature of the committee members.
  """
  @type certificate :: %{
          :keyset_hash => String.t(),
          :data_hash => String.t(),
          :timeout => DateTime.t(),
          :signers_mask => non_neg_integer(),
          :bls_signature => String.t()
        }

  @typedoc """
  AnyTrust committee member public key struct:
    * `trusted` - A boolean indicating whether the member is trusted.
    * `key` - The public key of the member.
    * `proof` - The proof of the member's public key.
  """
  @type signer :: %{
          :trusted => boolean(),
          :key => String.t(),
          optional(:proof) => String.t()
        }

  @typedoc """
  AnyTrust committee struct:
    * `threshold` - The threshold of honest members for the keyset.
    * `pubkeys` - A list of public keys of the committee members.
  """
  @type keyset :: %{
          :threshold => non_neg_integer(),
          :pubkeys => [signer()]
        }

  @doc """
    Parses batch accompanying data to extract AnyTrust data availability information.

    This function decodes the provided binary data to extract information related to
    AnyTrust data availability.

    ## Parameters
    - `batch_number`: The batch number associated with the AnyTrust data.
    - `binary_data`: The binary data to be parsed, containing AnyTrust data fields.

    ## Returns
    - `{:ok, :in_anytrust, da_info}` if the parsing is successful, where `da_info` is
      the AnyTrust data availability information struct.
    - `{:error, nil, nil}` if the parsing fails.
  """
  @spec parse_batch_accompanying_data(non_neg_integer(), binary()) ::
          {:ok, :in_anytrust, __MODULE__.t()} | {:error, nil, nil}
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

  def parse_batch_accompanying_data(batch_number, <<
        keyset_hash::binary-size(32),
        data_hash::binary-size(32),
        timeout::big-unsigned-integer-size(64),
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

  @doc """
    Transforms AnyTrust data availability information into database-ready records.

    Creates database records for both the DA certificate and its association with a batch
    number. Additionally checks if the certificate's keyset is already known or needs to
    be fetched from L1.

    When encountering duplicate data keys within the same processing chunk, the function
    compares timeout values and keeps only the record with the highest timeout, which
    ensures longer data availability without database constraint violations.

    ## Parameters
    - A tuple containing:
      - A map of already prepared DA records, where `data_key` maps to `DaMultiPurposeRecord.to_import()`
      - A list of already prepared batch-to-blob associations
    - `da_info`: The AnyTrust DA info struct containing the certificate data
    - `l1_connection_config`: Configuration for L1 connection, including:
      - `:sequencer_inbox_address`: Address of the Sequencer Inbox contract
      - `:json_rpc_named_arguments`: JSON RPC connection parameters
    - `cache`: A set of previously processed keyset hashes

    ## Returns
    - A tuple containing:
      - A tuple of updated record collections:
        - A map of DA records where `data_key` maps to the record, including the new
          certificate (`data_type: 0`) and possibly a new keyset (`data_type: 1`)
        - Batch-to-blob associations list with the new mapping
      - Updated keyset cache
  """
  @spec prepare_for_import(
          {%{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}, [Arbitrum.BatchToDaBlob.to_import()]},
          __MODULE__.t(),
          %{
            :sequencer_inbox_address => String.t(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
          },
          MapSet.t()
        ) ::
          {{%{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}, [Arbitrum.BatchToDaBlob.to_import()]}, MapSet.t()}
  def prepare_for_import({da_records_acc, batch_to_blob_acc}, %__MODULE__{} = da_info, l1_connection_config, cache) do
    data = %{
      keyset_hash: ArbitrumHelper.bytes_to_hex_str(da_info.keyset_hash),
      data_hash: ArbitrumHelper.bytes_to_hex_str(da_info.data_hash),
      timeout: da_info.timeout,
      signers_mask: da_info.signers_mask,
      bls_signature: ArbitrumHelper.bytes_to_hex_str(da_info.bls_signature)
    }

    # Create `DaMultiPurposeRecord` record
    da_record = %{
      data_type: 0,
      data_key: da_info.data_hash,
      data: data,
      # This field must be removed as soon as migration to a separate table for Batch-to-DA-record associations is completed.
      batch_number: nil
    }

    # Create `BatchToDaBlob` record
    batch_to_blob_record = %{
      batch_number: da_info.batch_number,
      data_blob_id: da_info.data_hash
    }

    # Check if a record with the same data_key already exists
    updated_da_records =
      case Map.get(da_records_acc, da_info.data_hash) do
        nil ->
          # No duplicate, add the new record
          Map.put(da_records_acc, da_info.data_hash, da_record)

        duplicate_record ->
          log_info("Found duplicate DA record #{ArbitrumHelper.bytes_to_hex_str(da_info.data_hash)}")
          # Found duplicate, compare timeout values
          timeout_in_duplicate = duplicate_record.data.timeout
          timeout_in_candidate = da_record.data.timeout

          if DateTime.compare(timeout_in_candidate, timeout_in_duplicate) == :gt do
            # New record has higher timeout, replace the existing one
            Map.put(da_records_acc, da_info.data_hash, da_record)
          else
            # Existing record has higher or equal timeout, keep it
            da_records_acc
          end
      end

    {check_result, keyset_map, updated_cache} = check_if_new_keyset(da_info.keyset_hash, l1_connection_config, cache)

    # Add keyset record if it's new
    final_da_records =
      case check_result do
        :new_keyset ->
          # If the keyset is new, add a new keyset record to the DA records list.
          # As per the nature of `DaMultiPurposeRecord` it can contain not only DA
          # certificates but also keysets.
          keyset_record = %{
            data_type: 1,
            data_key: da_info.keyset_hash,
            data: keyset_map,
            batch_number: nil
          }

          Map.put(updated_da_records, da_info.keyset_hash, keyset_record)

        _ ->
          updated_da_records
      end

    {{final_da_records, [batch_to_blob_record | batch_to_blob_acc]}, updated_cache}
  end

  # Verifies the existence of an AnyTrust committee keyset in the database and fetches it from L1 if not found.
  #
  # To avoid fetching the same keyset multiple times, the function uses a cache.
  #
  # ## Parameters
  # - `keyset_hash`: A binary representing the hash of the keyset.
  # - `l1_connection_config`: A map containing the address of the Sequencer Inbox
  #                           contract and configuration parameters for the JSON RPC
  #                           connection.
  # - `cache`: A set of unique elements used to cache the checked keysets.
  #
  # ## Returns
  # - `{:new_keyset, keyset_info, updated_cache}` if the keyset is not found and fetched from L1.
  # - `{:existing_keyset, nil, cache}` if the keyset is found in the cache or database.
  @spec check_if_new_keyset(
          binary(),
          %{
            :sequencer_inbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
          },
          MapSet.t()
        ) ::
          {:new_keyset, __MODULE__.keyset(), MapSet.t()}
          | {:existing_keyset, nil, MapSet.t()}
  defp check_if_new_keyset(keyset_hash, l1_connection_config, cache) do
    if MapSet.member?(cache, keyset_hash) do
      {:existing_keyset, nil, cache}
    else
      updated_cache = MapSet.put(cache, keyset_hash)

      case Db.anytrust_keyset_exists?(keyset_hash) do
        true ->
          {:existing_keyset, nil, updated_cache}

        false ->
          {:new_keyset, get_keyset_info_from_l1(keyset_hash, l1_connection_config), updated_cache}
      end
    end
  end

  # Retrieves and decodes AnyTrust committee keyset information from L1 using the provided keyset hash.
  #
  # This function fetches the block number when the keyset was applied, retrieves
  # the raw keyset data from L1, and decodes it to extract the threshold and public
  # keys information.
  #
  # ## Parameters
  # - `keyset_hash`: The hash of the keyset to be retrieved.
  # - A map containing:
  #   - `:sequencer_inbox_address`: The address of the Sequencer Inbox contract.
  #   - `:json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A map describing an AnyTrust committee.
  @spec get_keyset_info_from_l1(
          binary(),
          %{
            :sequencer_inbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments()
          }
        ) :: __MODULE__.keyset()
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
  end

  # Retrieves the raw data of a keyset by querying logs for the `SetValidKeyset` event.
  #
  # This function fetches logs for the `SetValidKeyset` event within a specific block
  # emitted by the Sequencer Inbox contract and extracts the keyset data if available.
  #
  # ## Parameters
  # - `keyset_hash`: The hash of the keyset to retrieve.
  # - `block_number`: The block number to search for the logs.
  # - `sequencer_inbox_address`: The address of the Sequencer Inbox contract.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - The raw data of the keyset if found, otherwise `nil`.
  @spec get_keyset_raw_data(
          binary(),
          non_neg_integer(),
          binary(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: binary() | nil
  defp get_keyset_raw_data(keyset_hash, block_number, sequencer_inbox_address, json_rpc_named_arguments) do
    {:ok, logs} =
      IndexerHelper.get_logs(
        block_number,
        block_number,
        sequencer_inbox_address,
        [ArbitrumEvents.set_valid_keyset(), ArbitrumHelper.bytes_to_hex_str(keyset_hash)],
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
    [keyset_data] = decode_data(event["data"], ArbitrumEvents.set_valid_keyset_unindexed_params())

    keyset_data
  end

  # Decodes an AnyTrust committee keyset from a binary input.
  #
  # This function extracts the threshold of committee members configured for the
  # keyset and the number of member public keys from the binary input, then decodes
  # the specified number of public keys.
  #
  # Implemented as per: https://github.com/OffchainLabs/nitro/blob/ad9ab00723e13cf98307b9b65774ad455594ef7b/arbstate/das_reader.go#L217-L248
  #
  # ## Parameters
  # - A binary input containing the threshold value, the number of public keys,
  #   and the public keys themselves.
  #
  # ## Returns
  # - A map describing an AnyTrust committee.
  @spec decode_keyset(binary()) :: __MODULE__.keyset()
  defp decode_keyset(<<
         threshold::big-unsigned-integer-size(64),
         num_keys::big-unsigned-integer-size(64),
         rest::binary
       >>)
       when num_keys <= 64 do
    {pubkeys, _} = decode_pubkeys(rest, num_keys, [])

    %{
      threshold: threshold,
      pubkeys: pubkeys
    }
  end

  # Decodes a list of AnyTrust committee member public keys from a binary input.
  #
  # This function recursively processes a binary input to extract a specified number
  # of public keys.
  #
  # ## Parameters
  # - `data`: The binary input containing the public keys.
  # - `num_keys`: The number of public keys to decode.
  # - `acc`: An accumulator list to collect the decoded public keys.
  #
  # ## Returns
  # - A tuple containing:
  #   - `{:error, "Insufficient data to decode public keys"}` if the input is insufficient
  #     to decode the specified number of keys.
  #   - A list of decoded AnyTrust committee member public keys and a binary entity
  #     of zero length, if successful.
  @spec decode_pubkeys(binary(), non_neg_integer(), [
          signer()
        ]) :: {:error, String.t()} | {[signer()], binary()}
  defp decode_pubkeys(<<>>, 0, acc), do: {Enum.reverse(acc), <<>>}
  defp decode_pubkeys(<<>>, _num_keys, _acc), do: {:error, "Insufficient data to decode public keys"}

  defp decode_pubkeys(data, num_keys, acc) when num_keys > 0 do
    <<high_byte, low_byte, rest::binary>> = data
    pubkey_len = high_byte * 256 + low_byte

    <<pubkey_data::binary-size(pubkey_len), remaining::binary>> = rest
    pubkey = parse_pubkey(pubkey_data)
    decode_pubkeys(remaining, num_keys - 1, [pubkey | acc])
  end

  # Parses a public key of an AnyTrust AnyTrust committee member from a binary input.
  #
  # This function extracts either the public key (for trusted sources) or the proof
  # bytes and key bytes (for untrusted sources).
  #
  # Implemented as per: https://github.com/OffchainLabs/nitro/blob/35bd2aa59611702e6403051af581fddda7c17f74/blsSignatures/blsSignatures.go#L206C6-L242
  #
  # ## Parameters
  # - A binary input containing the proof length and the rest of the data.
  #
  # ## Returns
  # - A map describing an AnyTrust committee member public key.
  @spec parse_pubkey(binary()) :: signer()
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

  @doc """
    Resolves conflicts between existing database records and candidate DA records.

    This function compares the timeout values of existing database records with candidate
    records that have the same data_key. It keeps only candidate records with higher timeout
    values than their corresponding database records, or those without matching database records.

    ## Parameters
    - `db_records`: A list of `Arbitrum.DaMultiPurposeRecord` retrieved from the database
    - `candidate_records`: A map where `data_key` maps to `Arbitrum.DaMultiPurposeRecord.to_import()`

    ## Returns
    - A list of `Arbitrum.DaMultiPurposeRecord.to_import()` after resolving conflicts
  """
  @spec resolve_conflict(
          [Arbitrum.DaMultiPurposeRecord.t()],
          %{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}
        ) :: [Arbitrum.DaMultiPurposeRecord.to_import()]

  def resolve_conflict([], candidate_records) do
    Map.values(candidate_records)
  end

  def resolve_conflict(db_records, candidate_records) do
    # Create a set of keys to exclude (those where DB record has equal or higher timeout)
    keys_to_exclude =
      Enum.reduce(db_records, MapSet.new(), fn db_record, acc ->
        data_key = db_record.data_key

        case Map.get(candidate_records, data_key) do
          nil ->
            # No matching candidate record, nothing to exclude
            acc

          candidate_record ->
            # Convert string timeout from DB to DateTime and compare with candidate timeout
            db_timeout = string_to_datetime(db_record.data["timeout"])
            candidate_timeout = candidate_record.data.timeout

            # credo:disable-for-lines:1 Credo.Check.Refactor.Nesting
            if DateTime.compare(candidate_timeout, db_timeout) == :gt do
              log_info(
                "Candidate DA record #{ArbitrumHelper.bytes_to_hex_str(data_key)} has higher timeout than DB record"
              )

              # Candidate has higher timeout, don't exclude
              acc
            else
              # DB record has higher or equal timeout, exclude this key
              log_info(
                "DA record #{ArbitrumHelper.bytes_to_hex_str(data_key)} already exists in DB with higher or equal timeout"
              )

              MapSet.put(acc, data_key)
            end
        end
      end)

    # Return only candidate records not in the exclude set
    candidate_records
    |> Enum.reject(fn {data_key, _record} -> MapSet.member?(keys_to_exclude, data_key) end)
    |> Enum.map(fn {_data_key, record} -> record end)
  end

  # Converts a string representation of a DateTime to a DateTime struct.
  # The string is expected to be in ISO 8601 format.
  #
  # ## Parameters
  # - `datetime_str`: A string representing a DateTime in ISO 8601 format
  #
  # ## Returns
  # - A DateTime struct if the conversion is successful
  # - Raises an error if the string cannot be parsed
  @spec string_to_datetime(String.t()) :: DateTime.t()
  defp string_to_datetime(datetime_str) when is_binary(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _offset} -> datetime
      {:error, reason} -> raise "Failed to parse datetime string: #{datetime_str}, reason: #{reason}"
    end
  end
end
