defmodule Explorer.Chain.Fhe.ParserTest do
  use Explorer.DataCase

  alias ABI.TypeEncoder
  alias Explorer.Chain.{Fhe.Parser, Hash, Log}
  alias Explorer.Helper

  describe "get_event_name/1" do
    test "returns correct event name for FheAdd" do
      assert "FheAdd" == Parser.get_event_name("0xdb9050d65240431621d61d6f94b970e63f53a67a5766614ee6e5c5bbd41c8e2e")
    end

    test "returns correct event name for TrivialEncrypt" do
      assert "TrivialEncrypt" ==
               Parser.get_event_name("0x063ccd1bba45151d91f6a418065047a3d048d058a922535747bb2b575a01d236")
    end

    test "returns Unknown for invalid event signature" do
      assert "Unknown" == Parser.get_event_name("0xinvalid")
    end

    test "handles case-insensitive topic" do
      assert "FheAdd" == Parser.get_event_name("0xDB9050D65240431621D61D6F94B970E63F53A67A5766614EE6E5C5BBD41C8E2E")
    end
  end

  describe "extract_caller/1" do
    test "extracts caller from Hash struct" do
      address_bytes = <<1::160>>
      # Create a 32-byte hash (12 bytes padding + 20 bytes address)
      full_hash_bytes = <<0::96, address_bytes::binary>>
      {:ok, hash} = Hash.cast(Hash.Full, "0x" <> Base.encode16(full_hash_bytes, case: :lower))

      result = Parser.extract_caller(hash)
      expected = "0x" <> Base.encode16(address_bytes, case: :lower)
      assert expected == result
    end

    test "extracts caller from binary topic" do
      address_bytes = <<1::160>>
      topic = <<0::96, address_bytes::binary>>

      result = Parser.extract_caller(topic)
      assert "0x" <> Base.encode16(address_bytes, case: :lower) == result
    end

    test "extracts caller from 32-byte binary topic" do
      # Test with a 32-byte binary (what a topic actually is)
      address_bytes =
        <<0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8,
          0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8, 0x11::8>>

      topic = <<0::96, address_bytes::binary>>

      result = Parser.extract_caller(topic)
      expected = "0x" <> Base.encode16(address_bytes, case: :lower)
      assert expected == result
    end

    test "returns nil for nil input" do
      assert nil == Parser.extract_caller(nil)
    end
  end

  describe "decode_event_data/2" do
    test "decodes binary operation (FheAdd)" do
      lhs = <<1::256>>
      rhs = <<2::256>>
      scalar_byte = <<0>>
      result = <<3::256>>

      data =
        "0x" <>
          Base.encode16(
            TypeEncoder.encode([lhs, rhs, scalar_byte, result], [{:bytes, 32}, {:bytes, 32}, {:bytes, 1}, {:bytes, 32}]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "FheAdd")

      assert decoded.lhs == lhs
      assert decoded.rhs == rhs
      assert decoded.scalar_byte == scalar_byte
      assert decoded.result == result
    end

    test "decodes unary operation (FheNeg)" do
      ct = <<1::256>>
      result = <<2::256>>

      data = "0x" <> Base.encode16(TypeEncoder.encode([ct, result], [{:bytes, 32}, {:bytes, 32}]), case: :lower)
      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "FheNeg")

      assert decoded.ct == ct
      assert decoded.result == result
    end

    test "decodes TrivialEncrypt operation" do
      pt = 123
      to_type = 1
      result = <<3::256>>

      data =
        "0x" <>
          Base.encode16(TypeEncoder.encode([pt, to_type, result], [{:uint, 256}, {:uint, 8}, {:bytes, 32}]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "TrivialEncrypt")

      assert decoded.plaintext == pt
      assert decoded.to_type == to_type
      assert decoded.result == result
    end

    test "decodes Cast operation" do
      ct = <<1::256>>
      to_type = 2
      result = <<3::256>>

      data =
        "0x" <>
          Base.encode16(TypeEncoder.encode([ct, to_type, result], [{:bytes, 32}, {:uint, 8}, {:bytes, 32}]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "Cast")

      assert decoded.ct == ct
      assert decoded.to_type == to_type
      assert decoded.result == result
    end

    test "decodes FheIfThenElse operation" do
      control = <<1::256>>
      if_true = <<2::256>>
      if_false = <<3::256>>
      result = <<4::256>>

      data =
        "0x" <>
          Base.encode16(
            TypeEncoder.encode([control, if_true, if_false, result], [
              {:bytes, 32},
              {:bytes, 32},
              {:bytes, 32},
              {:bytes, 32}
            ]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "FheIfThenElse")

      assert decoded.control == control
      assert decoded.if_true == if_true
      assert decoded.if_false == if_false
      assert decoded.result == result
    end

    test "decodes FheRand operation" do
      rand_type = 1
      seed = <<1::128>>
      result = <<2::256>>

      data =
        "0x" <>
          Base.encode16(TypeEncoder.encode([rand_type, seed, result], [{:uint, 8}, {:bytes, 16}, {:bytes, 32}]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "FheRand")

      assert decoded.rand_type == rand_type
      assert decoded.seed == seed
      assert decoded.result == result
    end

    test "decodes FheRandBounded operation" do
      upper_bound = 100
      rand_type = 1
      seed = <<1::128>>
      result = <<2::256>>

      data =
        "0x" <>
          Base.encode16(
            TypeEncoder.encode([upper_bound, rand_type, seed, result], [
              {:uint, 256},
              {:uint, 8},
              {:bytes, 16},
              {:bytes, 32}
            ]),
            case: :lower
          )

      log = %Log{data: data}

      decoded = Parser.decode_event_data(log, "FheRandBounded")

      assert decoded.upper_bound == upper_bound
      assert decoded.rand_type == rand_type
      assert decoded.seed == seed
      assert decoded.result == result
    end

    test "returns default result for unknown event" do
      log = %Log{data: <<>>}
      decoded = Parser.decode_event_data(log, "UnknownEvent")

      assert decoded.result == <<0::256>>
    end
  end

  describe "extract_fhe_type/2" do
    test "extracts type from TrivialEncrypt to_type" do
      operation_data = %{to_type: 2, result: <<0::256>>}
      assert "Uint8" == Parser.extract_fhe_type(operation_data, "TrivialEncrypt")
    end

    test "extracts all types from TrivialEncrypt to_type" do
      # Test all main types
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        operation_data = %{to_type: type_index, result: <<0::256>>}

        assert expected_type == Parser.extract_fhe_type(operation_data, "TrivialEncrypt"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from Cast input handle (ct)" do
      # Cast extracts type from input handle (ct), not to_type parameter
      # Type byte at position 30 (0-indexed) in the ct handle
      # ct handle with type 3 (Uint16) at byte 30
      ct = <<0::240, 3::8, 0::8>>
      operation_data = %{ct: ct, to_type: 5, result: <<0::256>>}
      assert "Uint16" == Parser.extract_fhe_type(operation_data, "Cast")
    end

    test "extracts all types from Cast input handle" do
      # Test all main types in Cast
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        ct = <<0::240, type_index::8, 0::8>>
        operation_data = %{ct: ct, to_type: 0, result: <<0::256>>}

        assert expected_type == Parser.extract_fhe_type(operation_data, "Cast"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from comparison operations LHS handle" do
      # Comparison operations (FheEq, FheNe, etc.) extract type from LHS handle, not result
      # LHS handle with type 2 (Uint8) at byte 30
      lhs = <<0::240, 2::8, 0::8>>
      operation_data = %{lhs: lhs, rhs: <<0::256>>, result: <<0::240, 6::8, 0::8>>}
      assert "Uint8" == Parser.extract_fhe_type(operation_data, "FheEq")
    end

    test "extracts all types from comparison operations LHS handle" do
      # Test all main types in comparison operations
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        lhs = <<0::240, type_index::8, 0::8>>
        operation_data = %{lhs: lhs, rhs: <<0::256>>, result: <<0::256>>}

        assert expected_type == Parser.extract_fhe_type(operation_data, "FheEq"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from result handle for most operations" do
      # Most operations extract type from result handle
      # Type byte at position 30 (0-indexed)
      # Result handle with type 2 (Uint8) at byte 30
      result = <<0::240, 2::8, 0::8>>
      operation_data = %{result: result}
      assert "Uint8" == Parser.extract_fhe_type(operation_data, "FheAdd")
    end

    test "extracts all types from result handle for binary operations" do
      # Test all main types in result handle
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        result = <<0::240, type_index::8, 0::8>>
        operation_data = %{result: result}

        assert expected_type == Parser.extract_fhe_type(operation_data, "FheAdd"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from unary operation input handle" do
      # Unary operations (Cast, FheNot, FheNeg) extract type from input handle (ct)
      # ct handle with type 4 (Uint32) at byte 30
      ct = <<0::240, 4::8, 0::8>>
      operation_data = %{ct: ct, result: <<0::256>>}
      assert "Uint32" == Parser.extract_fhe_type(operation_data, "FheNeg")
    end

    test "extracts all types from unary operation input handle" do
      # Test all main types in unary operations
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        ct = <<0::240, type_index::8, 0::8>>
        operation_data = %{ct: ct, result: <<0::256>>}

        assert expected_type == Parser.extract_fhe_type(operation_data, "FheNeg"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from FheRand randType parameter" do
      # rand_type: 2 = Uint8
      operation_data = %{rand_type: 2, seed: <<0::128>>, result: <<0::256>>}
      assert "Uint8" == Parser.extract_fhe_type(operation_data, "FheRand")
    end

    test "extracts all types from FheRand randType parameter" do
      # Test all main types in FheRand
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        operation_data = %{rand_type: type_index, seed: <<0::128>>, result: <<0::256>>}

        assert expected_type == Parser.extract_fhe_type(operation_data, "FheRand"),
               "Failed for type_index #{type_index}, expected #{expected_type}"
      end)
    end

    test "extracts type from FheRandBounded randType parameter" do
      # rand_type: 2 = Uint8
      operation_data = %{rand_type: 2, upper_bound: 100, seed: <<0::128>>, result: <<0::256>>}
      assert "Uint8" == Parser.extract_fhe_type(operation_data, "FheRandBounded")
    end

    test "returns Unknown for invalid result" do
      operation_data = %{result: <<>>}
      assert "Unknown" == Parser.extract_fhe_type(operation_data, "FheAdd")
    end

    test "returns Unknown for missing required data" do
      # TrivialEncrypt without to_type
      assert "Unknown" == Parser.extract_fhe_type(%{}, "TrivialEncrypt")

      # Cast without ct
      assert "Unknown" == Parser.extract_fhe_type(%{}, "Cast")

      # Comparison without lhs
      assert "Unknown" == Parser.extract_fhe_type(%{}, "FheEq")

      # FheRand without rand_type
      assert "Unknown" == Parser.extract_fhe_type(%{}, "FheRand")
    end
  end

  describe "extract_inputs/2" do
    test "extracts inputs for binary operation" do
      operation_data = %{lhs: <<1::256>>, rhs: <<2::256>>}
      inputs = Parser.extract_inputs(operation_data, "FheAdd")

      assert inputs.lhs == Base.encode16(<<1::256>>, case: :lower)
      assert inputs.rhs == Base.encode16(<<2::256>>, case: :lower)
    end

    test "extracts inputs for unary operation" do
      operation_data = %{ct: <<1::256>>}
      inputs = Parser.extract_inputs(operation_data, "FheNeg")

      assert inputs.ct == Base.encode16(<<1::256>>, case: :lower)
    end

    test "extracts inputs for FheIfThenElse" do
      operation_data = %{control: <<1::256>>, if_true: <<2::256>>, if_false: <<3::256>>}
      inputs = Parser.extract_inputs(operation_data, "FheIfThenElse")

      assert inputs.control == Base.encode16(<<1::256>>, case: :lower)
      assert inputs.if_true == Base.encode16(<<2::256>>, case: :lower)
      assert inputs.if_false == Base.encode16(<<3::256>>, case: :lower)
    end

    test "extracts inputs for TrivialEncrypt" do
      operation_data = %{plaintext: 123}
      inputs = Parser.extract_inputs(operation_data, "TrivialEncrypt")

      assert inputs.plaintext == 123
    end

    test "returns empty map for unknown operation" do
      operation_data = %{}
      inputs = Parser.extract_inputs(operation_data, "Unknown")

      assert inputs == %{}
    end
  end

  describe "calculate_hcu_cost/3" do
    test "calculates HCU cost for FheAdd operation" do
      cost = Parser.calculate_hcu_cost("FheAdd", "Uint8", false)
      assert is_integer(cost)
      assert cost > 0
    end

    test "calculates different cost for scalar vs non-scalar" do
      scalar_cost = Parser.calculate_hcu_cost("FheAdd", "Uint8", true)
      non_scalar_cost = Parser.calculate_hcu_cost("FheAdd", "Uint8", false)

      assert scalar_cost != non_scalar_cost
    end

    test "calculates HCU cost for all types in FheAdd" do
      # Test all main types for FheAdd non-scalar
      test_cases = [
        {"Uint8", 88_000},
        {"Uint16", 93_000},
        {"Uint32", 125_000},
        {"Uint64", 162_000},
        {"Uint128", 259_000}
      ]

      Enum.each(test_cases, fn {type, expected_cost} ->
        cost = Parser.calculate_hcu_cost("FheAdd", type, false)

        assert cost == expected_cost,
               "FheAdd non-scalar #{type} should cost #{expected_cost}, got #{cost}"
      end)

      # Test all main types for FheAdd scalar
      scalar_cases = [
        {"Uint8", 84_000},
        {"Uint16", 93_000},
        {"Uint32", 95_000},
        {"Uint64", 133_000},
        {"Uint128", 172_000}
      ]

      Enum.each(scalar_cases, fn {type, expected_cost} ->
        cost = Parser.calculate_hcu_cost("FheAdd", type, true)

        assert cost == expected_cost,
               "FheAdd scalar #{type} should cost #{expected_cost}, got #{cost}"
      end)
    end

    test "calculates HCU cost for FheGe all types" do
      # Test FheGe non-scalar for all types
      test_cases = [
        {"Uint8", 63_000},
        {"Uint16", 84_000},
        {"Uint32", 118_000},
        {"Uint64", 152_000},
        {"Uint128", 210_000}
      ]

      Enum.each(test_cases, fn {type, expected_cost} ->
        cost = Parser.calculate_hcu_cost("FheGe", type, false)

        assert cost == expected_cost,
               "FheGe non-scalar #{type} should cost #{expected_cost}, got #{cost}"
      end)
    end

    test "calculates HCU cost for FheIfThenElse all types" do
      # Test FheIfThenElse for all types
      test_cases = [
        {"Bool", 55_000},
        {"Uint8", 55_000},
        {"Uint16", 55_000},
        {"Uint32", 55_000},
        {"Uint64", 55_000},
        {"Uint128", 57_000}
      ]

      Enum.each(test_cases, fn {type, expected_cost} ->
        cost = Parser.calculate_hcu_cost("FheIfThenElse", type, false)

        assert cost == expected_cost,
               "FheIfThenElse #{type} should cost #{expected_cost}, got #{cost}"
      end)
    end

    test "calculates HCU cost for TrivialEncrypt all types" do
      # Test TrivialEncrypt for all types
      test_cases = [
        {"Bool", 32},
        {"Uint8", 32},
        {"Uint16", 32},
        {"Uint32", 32},
        {"Uint64", 32},
        {"Uint128", 32}
      ]

      Enum.each(test_cases, fn {type, expected_cost} ->
        cost = Parser.calculate_hcu_cost("TrivialEncrypt", type, false)

        assert cost == expected_cost,
               "TrivialEncrypt #{type} should cost #{expected_cost}, got #{cost}"
      end)
    end

    test "returns 0 for unknown operation" do
      cost = Parser.calculate_hcu_cost("UnknownOperation", "Uint8", false)
      assert cost == 0
    end

    test "returns 0 for unknown type" do
      cost = Parser.calculate_hcu_cost("FheAdd", "UnknownType", false)
      assert cost == 0
    end
  end

  describe "get_operation_type/1" do
    test "returns arithmetic for arithmetic operations" do
      assert "arithmetic" == Parser.get_operation_type("FheAdd")
      assert "arithmetic" == Parser.get_operation_type("FheSub")
      assert "arithmetic" == Parser.get_operation_type("FheMul")
      assert "arithmetic" == Parser.get_operation_type("FheDiv")
      assert "arithmetic" == Parser.get_operation_type("FheRem")
    end

    test "returns bitwise for bitwise operations" do
      assert "bitwise" == Parser.get_operation_type("FheBitAnd")
      assert "bitwise" == Parser.get_operation_type("FheBitOr")
      assert "bitwise" == Parser.get_operation_type("FheBitXor")
      assert "bitwise" == Parser.get_operation_type("FheShl")
      assert "bitwise" == Parser.get_operation_type("FheShr")
      assert "bitwise" == Parser.get_operation_type("FheRotl")
      assert "bitwise" == Parser.get_operation_type("FheRotr")
    end

    test "returns comparison for comparison operations" do
      assert "comparison" == Parser.get_operation_type("FheEq")
      assert "comparison" == Parser.get_operation_type("FheNe")
      assert "comparison" == Parser.get_operation_type("FheGe")
      assert "comparison" == Parser.get_operation_type("FheGt")
      assert "comparison" == Parser.get_operation_type("FheLe")
      assert "comparison" == Parser.get_operation_type("FheLt")
      assert "comparison" == Parser.get_operation_type("FheMin")
      assert "comparison" == Parser.get_operation_type("FheMax")
    end

    test "returns unary for unary operations" do
      assert "unary" == Parser.get_operation_type("FheNeg")
      assert "unary" == Parser.get_operation_type("FheNot")
    end

    test "returns control for control operations" do
      assert "control" == Parser.get_operation_type("FheIfThenElse")
    end

    test "returns encryption for encryption operations" do
      assert "encryption" == Parser.get_operation_type("TrivialEncrypt")
      assert "encryption" == Parser.get_operation_type("Cast")
    end

    test "returns random for random operations" do
      assert "random" == Parser.get_operation_type("FheRand")
      assert "random" == Parser.get_operation_type("FheRandBounded")
    end

    test "returns other for unknown operations" do
      assert "other" == Parser.get_operation_type("UnknownOperation")
    end
  end

  describe "FheOperatorPrices.get_type_name/1" do
    test "returns correct type name for all main types" do
      test_cases = [
        {0, "Bool"},
        {1, "Uint4"},
        {2, "Uint8"},
        {3, "Uint16"},
        {4, "Uint32"},
        {5, "Uint64"},
        {6, "Uint128"},
        {7, "Uint160"},
        {8, "Uint256"}
      ]

      Enum.each(test_cases, fn {type_index, expected_type} ->
        type_name = Explorer.Chain.FheOperatorPrices.get_type_name(type_index)

        assert type_name == expected_type,
               "Type index #{type_index} should map to #{expected_type}, got #{type_name}"
      end)
    end

    test "returns Unknown for invalid type index" do
      assert "Unknown" == Explorer.Chain.FheOperatorPrices.get_type_name(999)
      assert "Unknown" == Explorer.Chain.FheOperatorPrices.get_type_name(-1)
    end
  end

  describe "build_hcu_depth_map/1" do
    test "calculates depth for independent operations" do
      operations = [
        %{result: <<1::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 100, is_scalar: false},
        %{result: <<2::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 200, is_scalar: false}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      result1 = Base.encode16(<<1::256>>, case: :lower)
      result2 = Base.encode16(<<2::256>>, case: :lower)

      assert depth_map[result1] == 100
      assert depth_map[result2] == 200
    end

    test "calculates depth for dependent operations" do
      result1 = Base.encode16(<<1::256>>, case: :lower)
      result2 = Base.encode16(<<2::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 100, is_scalar: false},
        %{result: <<2::256>>, inputs: %{lhs: result1, rhs: "0x00"}, hcu_cost: 200, is_scalar: false}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      assert depth_map[result1] == 100
      # 100 (from result1) + 200 (current)
      assert depth_map[result2] == 300
    end

    test "calculates depth for scalar operations (only LHS depth)" do
      result1 = Base.encode16(<<1::256>>, case: :lower)
      result2 = Base.encode16(<<2::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 100, is_scalar: false},
        # Scalar operation: RHS is plain value, so only use LHS depth
        %{result: <<2::256>>, inputs: %{lhs: result1, rhs: "plain_value"}, hcu_cost: 200, is_scalar: true}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      assert depth_map[result1] == 100
      # Scalar: lhs_depth (100) + cost (200) = 300 (not max of lhs and rhs)
      assert depth_map[result2] == 300
    end

    test "calculates depth for non-scalar operations (max of LHS and RHS)" do
      result1 = Base.encode16(<<1::256>>, case: :lower)
      result2 = Base.encode16(<<2::256>>, case: :lower)
      result3 = Base.encode16(<<3::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 100, is_scalar: false},
        %{result: <<2::256>>, inputs: %{lhs: "0x00", rhs: "0x00"}, hcu_cost: 200, is_scalar: false},
        # Non-scalar: use max of both input depths
        %{result: <<3::256>>, inputs: %{lhs: result1, rhs: result2}, hcu_cost: 300, is_scalar: false}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      assert depth_map[result1] == 100
      assert depth_map[result2] == 200
      # Non-scalar: max(100, 200) + 300 = 500
      assert depth_map[result3] == 500
    end

    test "calculates depth for unary operations" do
      result1 = Base.encode16(<<1::256>>, case: :lower)
      result2 = Base.encode16(<<2::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{}, hcu_cost: 100},
        %{result: <<2::256>>, inputs: %{ct: result1}, hcu_cost: 200}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      assert depth_map[result1] == 100
      # Unary: ct_depth (100) + cost (200) = 300
      assert depth_map[result2] == 300
    end

    test "calculates depth for FheIfThenElse" do
      control = Base.encode16(<<1::256>>, case: :lower)
      if_true = Base.encode16(<<2::256>>, case: :lower)
      if_false = Base.encode16(<<3::256>>, case: :lower)
      result = Base.encode16(<<4::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{}, hcu_cost: 50},
        %{result: <<2::256>>, inputs: %{}, hcu_cost: 100},
        %{result: <<3::256>>, inputs: %{}, hcu_cost: 150},
        %{result: <<4::256>>, inputs: %{control: control, if_true: if_true, if_false: if_false}, hcu_cost: 200}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      # max(50, 100, 150) + 200
      assert depth_map[result] == 350
    end

    test "calculates depth for operations with no inputs" do
      result1 = Base.encode16(<<1::256>>, case: :lower)

      operations = [
        %{result: <<1::256>>, inputs: %{}, hcu_cost: 100}
      ]

      depth_map = Parser.build_hcu_depth_map(operations)

      # Operations with no inputs (TrivialEncrypt, FheRand, etc.) have depth = cost only
      assert depth_map[result1] == 100
    end
  end

  describe "all_fhe_events/0" do
    test "returns list of all FHE event signatures" do
      events = Parser.all_fhe_events()

      assert is_list(events)
      assert length(events) > 0
      assert "0xdb9050d65240431621d61d6f94b970e63f53a67a5766614ee6e5c5bbd41c8e2e" in events
    end
  end
end
