# credo:disable-for-this-file
defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """
  alias ABI.{FunctionSelector, TypeDecoder}
  alias Explorer.Chain

  @metadata_hash_prefix_0_4_23 "a165627a7a72305820"
  @metadata_hash_prefix_0_5_family_1 "65627a7a723"
  @metadata_hash_prefix_0_5_family_2 "5820"
  @metadata_hash_prefix_0_6_0 "a264697066735822"

  @experimental "6c6578706572696d656e74616cf5"
  @metadata_hash_common_suffix "64736f6c63"

  def verify(address_hash, contract_code, arguments_data, contract_source_code, contract_name) do
    arguments_data = arguments_data |> String.trim_trailing() |> String.trim_leading("0x")

    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    check_func = fn assumed_arguments -> assumed_arguments == arguments_data end

    if verify_older_version(creation_code, contract_code, check_func) do
      true
    else
      extract_constructor_arguments(creation_code, check_func, contract_source_code, contract_name)
    end
  end

  # Earlier versions of Solidity didn't have whisper code.
  # constructor argument were directly appended to source code
  defp verify_older_version(creation_code, contract_code, check_func) do
    creation_code
    |> String.split(contract_code)
    |> List.last()
    |> check_func.()
  end

  defp extract_constructor_arguments(code, check_func, contract_source_code, contract_name) do
    case code do
      # Solidity ~ 4.23 # https://solidity.readthedocs.io/en/v0.4.23/metadata.html
      @metadata_hash_prefix_0_4_23 <> <<_::binary-size(64)>> <> "0029" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_4_23
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @experimental <>
          @metadata_hash_common_suffix <>
          "43" <> <<_::binary-size(6)>> <> <<_::binary-size(4)>> <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @experimental <>
          <<_::binary-size(4)>> <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      # Solidity >= 0.5.10 https://solidity.readthedocs.io/en/v0.5.10/metadata.html
      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @metadata_hash_common_suffix <> "43" <> <<_::binary-size(6)>> <> "0032" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @metadata_hash_common_suffix <> "7826" <> <<_::binary-size(76)>> <> "0057" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @metadata_hash_common_suffix <> "7827" <> <<_::binary-size(78)>> <> "0057" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @metadata_hash_common_suffix <> "7828" <> <<_::binary-size(80)>> <> "0058" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      <<_::binary-size(2)>> <>
          @metadata_hash_prefix_0_5_family_1 <>
          <<_::binary-size(1)>> <>
          @metadata_hash_prefix_0_5_family_2 <>
          <<_::binary-size(64)>> <>
          @metadata_hash_common_suffix <> "7829" <> <<_::binary-size(82)>> <> "0059" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_5_family_1
        )

      # Solidity >= 0.6.0 https://github.com/ethereum/solidity/blob/develop/Changelog.md#060-2019-12-17
      # https://github.com/ethereum/solidity/blob/26b700771e9cc9c956f0503a05de69a1be427963/docs/metadata.rst#encoding-of-the-metadata-hash-in-the-bytecode
      # IPFS is used instead of Swarm
      # The current version of the Solidity compiler usually adds the following to the end of the deployed bytecode:
      # 0xa2
      # 0x64 'i' 'p' 'f' 's' 0x58 0x22 <34 bytes IPFS hash>
      # 0x64 's' 'o' 'l' 'c' 0x43 <3 byte version encoding>
      # 0x00 0x32
      # Note: there is a bug in the docs. Instead of 0x32, 0x33 should be used.
      # Fixing PR has been created https://github.com/ethereum/solidity/pull/8174
      @metadata_hash_prefix_0_6_0 <>
          <<_::binary-size(68)>> <>
          @metadata_hash_common_suffix <> "43" <> <<_::binary-size(6)>> <> "0033" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_6_0
        )

      @metadata_hash_prefix_0_6_0 <>
          <<_::binary-size(68)>> <>
          @metadata_hash_common_suffix <> "7826" <> <<_::binary-size(76)>> <> "0057" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_6_0
        )

      @metadata_hash_prefix_0_6_0 <>
          <<_::binary-size(68)>> <>
          @metadata_hash_common_suffix <> "7827" <> <<_::binary-size(78)>> <> "0057" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_6_0
        )

      @metadata_hash_prefix_0_6_0 <>
          <<_::binary-size(68)>> <>
          @metadata_hash_common_suffix <> "7828" <> <<_::binary-size(80)>> <> "0058" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_6_0
        )

      @metadata_hash_prefix_0_6_0 <>
          <<_::binary-size(68)>> <>
          @metadata_hash_common_suffix <> "7829" <> <<_::binary-size(82)>> <> "0059" <> constructor_arguments ->
        split_constructor_arguments_and_extract_check_func(
          constructor_arguments,
          check_func,
          contract_source_code,
          contract_name,
          @metadata_hash_prefix_0_6_0
        )

      <<>> ->
        false

      <<_::binary-size(2)>> <> rest ->
        extract_constructor_arguments(rest, check_func, contract_source_code, contract_name)
    end
  end

  defp is_constructor_arguments_still_has_metadata_prefix(constructor_arguments, prefix) do
    constructor_arguments_parts =
      constructor_arguments
      |> String.split(prefix)
      |> Enum.count()

    constructor_arguments_parts > 1
  end

  defp split_constructor_arguments_and_extract_check_func(constructor_arguments, nil, nil, nil, _metadata_hash_prefix), do: constructor_arguments

  defp split_constructor_arguments_and_extract_check_func(
         constructor_arguments,
         check_func,
         contract_source_code,
         contract_name,
         metadata_hash_prefix
       ) do
    if is_constructor_arguments_still_has_metadata_prefix(constructor_arguments, metadata_hash_prefix) do
      {ind, _} = :binary.match(constructor_arguments, metadata_hash_prefix)
      offset = if ind > 2, do: ind - 2, else: 0

      processed_constructor_arguments =
        if offset > 0 do
          <<_::binary-size(offset)>> <> rest = constructor_arguments
          rest
        else
          constructor_arguments
        end

      extract_constructor_arguments(processed_constructor_arguments, check_func, contract_source_code, contract_name)
    else
      extract_constructor_arguments_check_func(
        constructor_arguments,
        check_func,
        contract_source_code,
        contract_name
      )
    end
  end

  defp extract_constructor_arguments_check_func(constructor_arguments, check_func, contract_source_code, contract_name) do   
    check_func_result_before_removing_strings = check_func.(constructor_arguments)

    constructor_arguments =
      remove_require_messages_from_constructor_arguments(contract_source_code, constructor_arguments, contract_name)

    filtered_constructor_arguments =
      remove_keccak256_strings_from_constructor_arguments(contract_source_code, constructor_arguments, contract_name)

    check_func_result = check_func.(filtered_constructor_arguments)

    cond do
      check_func_result_before_removing_strings -> 
        check_func_result_before_removing_strings
      check_func_result ->
        check_func_result
    true ->
      output =
        extract_constructor_arguments(filtered_constructor_arguments, check_func, contract_source_code, contract_name)

      if output do
        output
      else
        # https://github.com/blockscout/blockscout/pull/4764
        clean_constructor_arguments =
          remove_substring_of_require_messages(filtered_constructor_arguments, contract_source_code, contract_name)

        check_func.(clean_constructor_arguments)
      end
    end
  end

  defp remove_substring_of_require_messages(constructor_arguments, contract_source_code, contract_name) do
    require_msgs =
      contract_source_code
      |> extract_require_messages_from_constructor(contract_name)
      |> Enum.filter(fn require_msg -> require_msg != nil end)

    longest_substring_to_delete =
      Enum.reduce(require_msgs, "", fn msg, best_match ->
        case String.myers_difference(constructor_arguments, msg) do
          [{:eq, match} | _] ->
            if String.length(match) > String.length(best_match) do
              match
            else
              best_match
            end

          _ ->
            best_match
        end
      end)

    [_, cleaned_constructor_arguments] = String.split(constructor_arguments, longest_substring_to_delete, parts: 2)
    cleaned_constructor_arguments
  end

  def remove_require_messages_from_constructor_arguments(contract_source_code, constructor_arguments, contract_name) do
    all_msgs =
      contract_source_code
      |> extract_require_messages_from_constructor(contract_name)

    filtered_msgs =
      all_msgs
      |> Enum.filter(fn require_msg -> require_msg != nil end)

    msgs_list =
      filtered_msgs
      |> Enum.reverse()

    Enum.reduce(msgs_list, constructor_arguments, fn msg, pure_constructor_arguments ->
      case String.split(pure_constructor_arguments, msg, parts: 2) do
        [_, constructor_arguments_part] ->
          constructor_arguments_part

        [_] ->
          pure_constructor_arguments
      end
    end)
  end

  def remove_keccak256_strings_from_constructor_arguments(contract_source_code, constructor_arguments, contract_name) do
    all_strings =
      contract_source_code
      |> extract_strings_from_constructor(contract_name)

    strings_list =
      all_strings
      |> Enum.reverse()

    Enum.reduce(strings_list, constructor_arguments, fn msg, pure_constructor_arguments ->
      case String.split(pure_constructor_arguments, msg, parts: 2) do
        [_, constructor_arguments_part] ->
          constructor_arguments_part

        [_] ->
          pure_constructor_arguments
      end
    end)
  end

  def find_constructor_arguments(address_hash, abi, contract_source_code, contract_name) do
    creation_code =
      address_hash
      |> Chain.contract_creation_input_data()
      |> String.replace("0x", "")

    check_func = parse_constructor_and_return_check_func(abi)

    extract_constructor_arguments(creation_code, check_func, contract_source_code, contract_name)
  end

  defp parse_constructor_and_return_check_func(abi) do
    constructor_abi = Enum.find(abi, fn el -> el["type"] == "constructor" && el["inputs"] != [] end)

    input_types = Enum.map(constructor_abi["inputs"], &FunctionSelector.parse_specification_type/1)

    fn assumed_arguments ->
      try do
        _ =
          assumed_arguments
          |> Base.decode16!(case: :mixed)
          |> TypeDecoder.decode_raw(input_types)

        assumed_arguments
      rescue
        _ ->
          false
      end
    end
  end

  def extract_require_messages_from_constructor(contract_source_code, _contract_name) do
    # todo: _contract_name is for parsing of actually used constructor for concrete contract 
    require_contents = find_all_requires(contract_source_code)

    messages_list =
      Enum.reduce(require_contents, [], fn require_content, msgs ->
        msg = get_require_message_hex(require_content)
        if msg, do: [msg | msgs], else: msgs
      end)

    if messages_list, do: messages_list, else: []
  end

  def extract_strings_from_constructor(contract_source_code, _contract_name) do
    keccak256_contents = find_all_strings(contract_source_code)

    strings_list =
      Enum.reduce(keccak256_contents, [], fn keccak256_content, strs ->
        str = get_keccak256_string_hex(keccak256_content)
        if str, do: [str | strs], else: strs
      end)

    if strings_list, do: strings_list, else: []
  end

  def find_constructor_content(contract_source_code) do
    case String.split(contract_source_code, "constructor", parts: 2) do
      [_, right_from_contstructor] ->
        [_, right_from_contstructor_inside] = String.split(right_from_contstructor, "{", parts: 2)
        [constructor, _] = String.split(right_from_contstructor_inside, "}", parts: 2)
        constructor

      [_] ->
        nil
    end
  end

  def find_all_requires(contract_source_code) do
    if contract_source_code do
      trimmed_source_code =
        contract_source_code
        |> String.replace(~r/ +/, " ")
        |> String.replace("require(", "require (")

      [_ | requires] =
        trimmed_source_code
        |> String.split("require (")

      Enum.reduce(requires, [], fn right_from_require, requires_list ->
        [require_content | _] = String.split(right_from_require, ");", parts: 2)
        [require_content | requires_list]
      end)
    else
      []
    end
  end

  def find_all_strings(contract_source_code) do
    if contract_source_code do
      [_ | keccak256s] = String.split(contract_source_code, "keccak256")

      Enum.reduce(keccak256s, [], fn right_from_keccak256, keccak256s_list ->
        parts = String.split(right_from_keccak256, "\"")

        if Enum.count(parts) >= 3 do
          [_ | [right_from_keccak256_inside]] = String.split(right_from_keccak256, "\"", parts: 2)
          [keccak256_content | _] = String.split(right_from_keccak256_inside, "\"", parts: 2)
          [keccak256_content | keccak256s_list]
        else
          keccak256s_list
        end
      end)
    else
      []
    end
  end

  def get_require_message_hex(require_content) do
    parts = String.split(require_content, ",")

    if Enum.count(parts) > 1 do
      [msg] = Enum.take(parts, -1)

      msg
      |> String.trim()
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.trim_leading("'")
      |> String.trim_trailing("'")
      |> Base.encode16(case: :lower)
    else
      nil
    end
  end

  def get_keccak256_string_hex(keccak256_content) do
    if keccak256_content !== "" do
      keccak256_content
      |> String.trim()
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.trim_leading("'")
      |> String.trim_trailing("'")
      |> Base.encode16(case: :lower)
    else
      nil
    end
  end

  def experimental_find_constructor_args(rest_creation, rest_generated, abi) do
    got_args =
      rest_creation
      |> String.split(extract_constructor_arguments(rest_generated, nil, nil, nil))
      |> List.last()
    
    abi
    |> parse_constructor_and_return_check_func()
    |> (&(&1.(got_args))).()
  end
end
