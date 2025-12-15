defmodule Explorer.Chain.Fhe.Parser do
  @moduledoc """
  Logic for parsing FHE operations from transaction logs.
  """

  require Logger

  alias Explorer.Chain.{Hash, FheOperatorPrices, Log}
  alias Explorer.Helper

  # FHE Event Signatures (Keccak-256 hashes)
  @fhe_add_event "0xdb9050d65240431621d61d6f94b970e63f53a67a5766614ee6e5c5bbd41c8e2e"
  @fhe_sub_event "0xeb6d37bd271abe1395b21d6d78f3487d6584862872c29ffd3f90736ee99b7393"
  @fhe_mul_event "0x215346a4f9f975e6d5484e290bd4e53ca14453a9d282ebd3ccedb2a0f171753d"
  @fhe_div_event "0x3bab2ee0e2f90f4690c6a87bf63cf1a6b626086e95f231860b152966e8dabbf7"
  @fhe_rem_event "0x0e691cd0bf8c4e9308e4ced1bb9c964117dc5c5bb9b9ab5bdfebf2c9b13a897c"
  @fhe_bit_and_event "0xe42486b0ccdbef81a2075c48c8e515c079aea73c8b82429997c72a2fe1bf4fef"
  @fhe_bit_or_event "0x56df279bbfb03d9ed097bbe2f28d520ca0c1161206327926e98664d70d2c24c4"
  @fhe_bit_xor_event "0x4d32284bd3193ecaa44e1ceca32f41c5d6c32803a92e07967dd3ee4229721582"
  @fhe_shl_event "0xe84282aaebcca698443e39a2a948a345d0d2ebc654af5cb657a2d7e8053bf6cb"
  @fhe_shr_event "0x324220bfc9cb158b492991c03c309cd86e5345cac45aacae2092ddabe31fa3d8"
  @fhe_rotl_event "0xeb0e4f8dc74058194d0602425fe602f955c222200f7f10c6fe67992f7b24c7e9"
  @fhe_rotr_event "0xc148675905d07ad5496f8ef4d8195c907503f3ec12fd10ed5f21240abc693634"
  @fhe_eq_event "0xb3d5c664ec86575818e8d75ff25c5f867250df8954088549c41c848cd10e76cb"
  @fhe_ne_event "0x6960c1e88f61c352dba34d1bbf6753e302795264d5d8ae82f7983c7004651e5d"
  @fhe_ge_event "0x38c3a63c4230de5b741f494ffb54e3087104030279bc7bccee8ad9ad31712b21"
  @fhe_gt_event "0xc9ff8f0d18a3f766ce5de3de216076050140e4fc2652f5e0e745f6fc836cda8b"
  @fhe_le_event "0xdef2e704a077284a07f3d0b436db88f5d981b69f58ab7c1ae623252718a6de01"
  @fhe_lt_event "0x0d483b100d8c73b208984ec697caa3091521ee5525ce69edcf97d7e395d3d059"
  @fhe_min_event "0xc11d62b13c360a83082487064be1ec0878b2f0be4f012bf59f89e128063d47ff"
  @fhe_max_event "0xfd7c9208f956bf0c6ab76a667f04361245ad3e0a2d0eff92eb827acfcca68ea9"
  @fhe_neg_event "0x8c664d3c3ca583fc5803b8a91c49644bbd9550bfa87967c73ad1de83027768c0"
  @fhe_not_event "0x55aff4cc7a3d160c83f1f15b818011ede841a0b4597fb14dcd3603df3a11e5e0"
  @trivial_encrypt_event "0x063ccd1bba45151d91f6a418065047a3d048d058a922535747bb2b575a01d236"
  @cast_event "0x31ccae6a2f8e3ced1692f77c8f668133e4afdaaa35afe844ff4659a6c27e627f"
  @fhe_if_then_else_event "0x60be9d61aad849facc28c38b048cb5c4be3420b8fa2233e08cfa06be1b6d1c3e"
  @fhe_rand_event "0x0c8aca6017003326051e19913ef02631f24b801125e1fa8a1d812e868319fda6"
  @fhe_rand_bounded_event "0x5222d96b836727a1d6fe1ee9aef27f9bb507bd41794defa376ff6c648aaf8ff1"

  @binary_operations [
    @fhe_add_event, @fhe_sub_event, @fhe_mul_event, @fhe_div_event, @fhe_rem_event,
    @fhe_bit_and_event, @fhe_bit_or_event, @fhe_bit_xor_event,
    @fhe_shl_event, @fhe_shr_event, @fhe_rotl_event, @fhe_rotr_event,
    @fhe_eq_event, @fhe_ne_event, @fhe_ge_event, @fhe_gt_event,
    @fhe_le_event, @fhe_lt_event, @fhe_min_event, @fhe_max_event
  ]

  @unary_operations [@fhe_neg_event, @fhe_not_event]

  @all_fhe_events @binary_operations ++ @unary_operations ++ [
    @trivial_encrypt_event, @cast_event, @fhe_if_then_else_event,
    @fhe_rand_event, @fhe_rand_bounded_event
  ]

  @event_names %{
    @fhe_add_event => "FheAdd",
    @fhe_sub_event => "FheSub",
    @fhe_mul_event => "FheMul",
    @fhe_div_event => "FheDiv",
    @fhe_rem_event => "FheRem",
    @fhe_bit_and_event => "FheBitAnd",
    @fhe_bit_or_event => "FheBitOr",
    @fhe_bit_xor_event => "FheBitXor",
    @fhe_shl_event => "FheShl",
    @fhe_shr_event => "FheShr",
    @fhe_rotl_event => "FheRotl",
    @fhe_rotr_event => "FheRotr",
    @fhe_eq_event => "FheEq",
    @fhe_ne_event => "FheNe",
    @fhe_ge_event => "FheGe",
    @fhe_gt_event => "FheGt",
    @fhe_le_event => "FheLe",
    @fhe_lt_event => "FheLt",
    @fhe_min_event => "FheMin",
    @fhe_max_event => "FheMax",
    @fhe_neg_event => "FheNeg",
    @fhe_not_event => "FheNot",
    @trivial_encrypt_event => "TrivialEncrypt",
    @cast_event => "Cast",
    @fhe_if_then_else_event => "FheIfThenElse",
    @fhe_rand_event => "FheRand",
    @fhe_rand_bounded_event => "FheRandBounded"
  }

  @doc """
  Returns the list of all FHE event topics.
  """
  def all_fhe_events, do: @all_fhe_events

  @doc """
  Get event name from event signature hash.
  """
  def get_event_name(topic) do
    normalized_topic = String.downcase(to_string(topic))
    Map.get(@event_names, normalized_topic, "Unknown")
  end

  @doc """
  Extract caller address from indexed topic.
  """
  def extract_caller(nil), do: nil

  def extract_caller(topic) when is_binary(topic) and byte_size(topic) < 32, do: nil

  def extract_caller(topic) do
    case topic do
      %Hash{} = hash ->
        if byte_size(hash.bytes) == 32 do
          <<_::binary-size(12), address_bytes::binary-size(20)>> = hash.bytes
          "0x" <> Base.encode16(address_bytes, case: :lower)
        else
          nil
        end
      
      binary when is_binary(binary) ->
        if byte_size(binary) >= 32 do
          <<_::binary-size(12), address_bytes::binary-size(20)>> = binary
          "0x" <> Base.encode16(address_bytes, case: :lower)
        else
          nil
        end
      
      _ ->
        topic_str = to_string(topic) |> String.downcase()
        if String.starts_with?(topic_str, "0x") do
          "0x" <> String.slice(topic_str, -40, 40)
        else
          if String.length(topic_str) >= 40 do
            "0x" <> String.slice(topic_str, -40, 40)
          else
            topic_str
          end
        end
    end
  end

  @doc """
  Decode event data based on event type.
  """
  def decode_event_data(%{data: data} = _log, event_name) when event_name in [
    "FheAdd", "FheSub", "FheMul", "FheDiv", "FheRem",
    "FheBitAnd", "FheBitOr", "FheBitXor",
    "FheShl", "FheShr", "FheRotl", "FheRotr",
    "FheEq", "FheNe", "FheGe", "FheGt", "FheLe", "FheLt",
    "FheMin", "FheMax"
  ] do
    # Binary operations: (bytes32 lhs, bytes32 rhs, bytes1 scalarByte, bytes32 result)
    [lhs, rhs, scalar_byte, result] = Helper.decode_data(data, [{:bytes, 32}, {:bytes, 32}, {:bytes, 1}, {:bytes, 32}])

    %{
      lhs: lhs,
      rhs: rhs,
      scalar_byte: scalar_byte,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, event_name) when event_name in ["FheNeg", "FheNot"] do
    # Unary operations: (bytes32 ct, bytes32 result)
    [ct, result] = Helper.decode_data(data, [{:bytes, 32}, {:bytes, 32}])

    %{
      ct: ct,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, "TrivialEncrypt") do
    # TrivialEncrypt(address indexed caller, uint256 pt, uint8 toType, bytes32 result)
    [pt, to_type, result] = Helper.decode_data(data, [{:uint, 256}, {:uint, 8}, {:bytes, 32}])

    %{
      plaintext: pt,
      to_type: to_type,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, "Cast") do
    # Cast(address indexed caller, bytes32 ct, uint8 toType, bytes32 result)
    [ct, to_type, result] = Helper.decode_data(data, [{:bytes, 32}, {:uint, 8}, {:bytes, 32}])

    %{
      ct: ct,
      to_type: to_type,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, "FheIfThenElse") do
    # FheIfThenElse(address indexed caller, bytes32 control, bytes32 ifTrue, bytes32 ifFalse, bytes32 result)
    [control, if_true, if_false, result] = Helper.decode_data(data, [{:bytes, 32}, {:bytes, 32}, {:bytes, 32}, {:bytes, 32}])

    %{
      control: control,
      if_true: if_true,
      if_false: if_false,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, "FheRand") do
    # FheRand(address indexed caller, uint8 randType, bytes16 seed, bytes32 result)
    [rand_type, seed, result] = Helper.decode_data(data, [{:uint, 8}, {:bytes, 16}, {:bytes, 32}])

    %{
      rand_type: rand_type,
      seed: seed,
      result: result
    }
  end

  def decode_event_data(%{data: data} = _log, "FheRandBounded") do
    # FheRandBounded(address indexed caller, uint256 upperBound, uint8 randType, bytes16 seed, bytes32 result)
    [upper_bound, rand_type, seed, result] = Helper.decode_data(data, [{:uint, 256}, {:uint, 8}, {:bytes, 16}, {:bytes, 32}])

    %{
      upper_bound: upper_bound,
      rand_type: rand_type,
      seed: seed,
      result: result
    }
  end

  def decode_event_data(%Log{} = _log, _event_name) do
    %{result: <<0::256>>}
  end

  @doc """
  Extract FHE type from result handle or to_type.
  """
  def extract_fhe_type(operation_data, event_name) do
    case event_name do
      "TrivialEncrypt" ->
        if operation_data[:to_type] do
          FheOperatorPrices.get_type_name(operation_data.to_type)
        else
          extract_fhe_type_from_result(operation_data.result)
        end
      "Cast" ->
        if operation_data[:to_type] do
          FheOperatorPrices.get_type_name(operation_data.to_type)
        else
          extract_fhe_type_from_result(operation_data.result)
        end
      _ ->
        extract_fhe_type_from_result(operation_data.result)
    end
  end

  defp extract_fhe_type_from_result(result) when is_binary(result) do
    result_size = byte_size(result)
    
    if result_size >= 32 do
      # Extract byte 30 (0-indexed, second to last byte)
      <<_prefix::binary-size(30), type_byte::8, _suffix::binary-size(1)>> = result
      FheOperatorPrices.get_type_name(type_byte)
    else
      "Unknown"
    end
  end

  defp extract_fhe_type_from_result(_), do: "Unknown"

  @doc """
  Extract inputs based on operation type.
  """
  def extract_inputs(%{lhs: lhs, rhs: rhs}, _event_name) when not is_nil(lhs) do
    %{
      lhs: Base.encode16(lhs, case: :lower),
      rhs: Base.encode16(rhs, case: :lower)
    }
  end

  def extract_inputs(%{ct: ct}, _event_name) when not is_nil(ct) do
    %{ct: Base.encode16(ct, case: :lower)}
  end

  def extract_inputs(%{control: control, if_true: if_true, if_false: if_false}, "FheIfThenElse") do
    %{
      control: Base.encode16(control, case: :lower),
      if_true: Base.encode16(if_true, case: :lower),
      if_false: Base.encode16(if_false, case: :lower)
    }
  end

  def extract_inputs(%{plaintext: pt}, "TrivialEncrypt") do
    %{plaintext: pt}
  end

  def extract_inputs(_, _), do: %{}

  @doc """
  Calculate HCU cost for an operation.
  """
  def calculate_hcu_cost(event_name, fhe_type, is_scalar) do
    operation_key = event_name_to_operation_key(event_name)
    FheOperatorPrices.get_price(operation_key, fhe_type, is_scalar)
  end

  def event_name_to_operation_key("FheAdd"), do: "fheAdd"
  def event_name_to_operation_key("FheSub"), do: "fheSub"
  def event_name_to_operation_key("FheMul"), do: "fheMul"
  def event_name_to_operation_key("FheDiv"), do: "fheDiv"
  def event_name_to_operation_key("FheRem"), do: "fheRem"
  def event_name_to_operation_key("FheBitAnd"), do: "fheBitAnd"
  def event_name_to_operation_key("FheBitOr"), do: "fheBitOr"
  def event_name_to_operation_key("FheBitXor"), do: "fheBitXor"
  def event_name_to_operation_key("FheShl"), do: "fheShl"
  def event_name_to_operation_key("FheShr"), do: "fheShr"
  def event_name_to_operation_key("FheRotl"), do: "fheRotl"
  def event_name_to_operation_key("FheRotr"), do: "fheRotr"
  def event_name_to_operation_key("FheEq"), do: "fheEq"
  def event_name_to_operation_key("FheNe"), do: "fheNe"
  def event_name_to_operation_key("FheGe"), do: "fheGe"
  def event_name_to_operation_key("FheGt"), do: "fheGt"
  def event_name_to_operation_key("FheLe"), do: "fheLe"
  def event_name_to_operation_key("FheLt"), do: "fheLt"
  def event_name_to_operation_key("FheMin"), do: "fheMin"
  def event_name_to_operation_key("FheMax"), do: "fheMax"
  def event_name_to_operation_key("FheNeg"), do: "fheNeg"
  def event_name_to_operation_key("FheNot"), do: "fheNot"
  def event_name_to_operation_key("TrivialEncrypt"), do: "trivialEncrypt"
  def event_name_to_operation_key("Cast"), do: "cast"
  def event_name_to_operation_key("FheIfThenElse"), do: "ifThenElse"
  def event_name_to_operation_key("FheRand"), do: "fheRand"
  def event_name_to_operation_key("FheRandBounded"), do: "fheRandBounded"
  def event_name_to_operation_key(_), do: "unknown"

  @doc """
  Get operation category from event name.
  """
  def get_operation_type(event_name) do
    cond do
      event_name in ["FheAdd", "FheSub", "FheMul", "FheDiv", "FheRem"] -> "arithmetic"
      event_name in ["FheBitAnd", "FheBitOr", "FheBitXor", "FheShl", "FheShr", "FheRotl", "FheRotr"] -> "bitwise"
      event_name in ["FheEq", "FheNe", "FheGe", "FheGt", "FheLe", "FheLt", "FheMin", "FheMax"] -> "comparison"
      event_name in ["FheNeg", "FheNot"] -> "unary"
      event_name in ["FheIfThenElse"] -> "control"
      event_name in ["TrivialEncrypt", "Cast"] -> "encryption"
      event_name in ["FheRand", "FheRandBounded"] -> "random"
      true -> "other"
    end
  end

  @doc """
  Build HCU depth map tracking cumulative HCU for each handle.
  """
  def build_hcu_depth_map(operations) do
    Enum.reduce(operations, %{}, fn op, acc ->
      result_handle = if is_binary(op.result), do: Base.encode16(op.result, case: :lower), else: nil
      
      if is_nil(result_handle) do
        acc
      else
        # For binary operations, depth is max of input depths + current cost
        depth = case op.inputs do
        %{lhs: lhs, rhs: rhs} ->
          lhs_depth = Map.get(acc, lhs, 0)
          rhs_depth = Map.get(acc, rhs, 0)
          max(lhs_depth, rhs_depth) + op.hcu_cost
        
        %{control: control, if_true: if_true, if_false: if_false} ->
            control_depth = Map.get(acc, control, 0)
            true_depth = Map.get(acc, if_true, 0)
            false_depth = Map.get(acc, if_false, 0)
            max(control_depth, max(true_depth, false_depth)) + op.hcu_cost
        
        %{ct: ct} ->
            ct_depth = Map.get(acc, ct, 0)
            ct_depth + op.hcu_cost

         _ ->
            op.hcu_cost
        end

        Map.put(acc, result_handle, depth)
      end
    end)
  end
end
