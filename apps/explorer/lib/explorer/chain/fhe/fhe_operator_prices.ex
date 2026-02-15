defmodule Explorer.Chain.FheOperatorPrices do
  @moduledoc """
  HCU (Homomorphic Computation Units) price data for FHE operations.
  Ported from https://github.com/zama-ai/fhevm/blob/main/library-solidity/codegen/src/operatorsPrices.ts
  """

  @operator_prices %{
    "fheAdd" => %{
      scalar: %{
        "Uint8" => 84_000,
        "Uint16" => 93_000,
        "Uint32" => 95_000,
        "Uint64" => 133_000,
        "Uint128" => 172_000
      },
      non_scalar: %{
        "Uint8" => 88_000,
        "Uint16" => 93_000,
        "Uint32" => 125_000,
        "Uint64" => 162_000,
        "Uint128" => 259_000
      }
    },
    "fheSub" => %{
      scalar: %{
        "Uint8" => 84_000,
        "Uint16" => 93_000,
        "Uint32" => 95_000,
        "Uint64" => 133_000,
        "Uint128" => 172_000
      },
      non_scalar: %{
        "Uint8" => 91_000,
        "Uint16" => 93_000,
        "Uint32" => 125_000,
        "Uint64" => 162_000,
        "Uint128" => 260_000
      }
    },
    "fheMul" => %{
      scalar: %{
        "Uint8" => 122_000,
        "Uint16" => 193_000,
        "Uint32" => 265_000,
        "Uint64" => 365_000,
        "Uint128" => 696_000
      },
      non_scalar: %{
        "Uint8" => 150_000,
        "Uint16" => 222_000,
        "Uint32" => 328_000,
        "Uint64" => 596_000,
        "Uint128" => 1_686_000
      }
    },
    "fheDiv" => %{
      scalar: %{
        "Uint8" => 210_000,
        "Uint16" => 302_000,
        "Uint32" => 438_000,
        "Uint64" => 715_000,
        "Uint128" => 1_225_000
      }
    },
    "fheRem" => %{
      scalar: %{
        "Uint8" => 440_000,
        "Uint16" => 580_000,
        "Uint32" => 792_000,
        "Uint64" => 1_153_000,
        "Uint128" => 1_943_000
      }
    },
    "fheBitAnd" => %{
      scalar: %{
        "Bool" => 22_000,
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      },
      non_scalar: %{
        "Bool" => 25_000,
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      }
    },
    "fheBitOr" => %{
      scalar: %{
        "Bool" => 22_000,
        "Uint8" => 30_000,
        "Uint16" => 30_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      },
      non_scalar: %{
        "Bool" => 24_000,
        "Uint8" => 30_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      }
    },
    "fheBitXor" => %{
      scalar: %{
        "Bool" => 22_000,
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 39_000
      },
      non_scalar: %{
        "Bool" => 22_000,
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 39_000
      }
    },
    "fheShl" => %{
      scalar: %{
        "Uint8" => 32_000,
        "Uint16" => 32_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 39_000
      },
      non_scalar: %{
        "Uint8" => 92_000,
        "Uint16" => 125_000,
        "Uint32" => 162_000,
        "Uint64" => 208_000,
        "Uint128" => 272_000,
        "Uint256" => 378_000
      }
    },
    "fheShr" => %{
      scalar: %{
        "Uint8" => 32_000,
        "Uint16" => 32_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      },
      non_scalar: %{
        "Uint8" => 91_000,
        "Uint16" => 123_000,
        "Uint32" => 163_000,
        "Uint64" => 209_000,
        "Uint128" => 272_000,
        "Uint256" => 369_000
      }
    },
    "fheRotl" => %{
      scalar: %{
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 38_000
      },
      non_scalar: %{
        "Uint8" => 91_000,
        "Uint16" => 125_000,
        "Uint32" => 163_000,
        "Uint64" => 209_000,
        "Uint128" => 278_000,
        "Uint256" => 378_000
      }
    },
    "fheRotr" => %{
      scalar: %{
        "Uint8" => 31_000,
        "Uint16" => 31_000,
        "Uint32" => 32_000,
        "Uint64" => 34_000,
        "Uint128" => 37_000,
        "Uint256" => 40_000
      },
      non_scalar: %{
        "Uint8" => 93_000,
        "Uint16" => 125_000,
        "Uint32" => 160_000,
        "Uint64" => 209_000,
        "Uint128" => 283_000,
        "Uint256" => 375_000
      }
    },
    "fheEq" => %{
      scalar: %{
        "Bool" => 25_000,
        "Uint8" => 55_000,
        "Uint16" => 55_000,
        "Uint32" => 82_000,
        "Uint64" => 83_000,
        "Uint128" => 117_000,
        "Uint160" => 117_000,
        "Uint256" => 118_000
      },
      non_scalar: %{
        "Bool" => 26_000,
        "Uint8" => 55_000,
        "Uint16" => 83_000,
        "Uint32" => 86_000,
        "Uint64" => 120_000,
        "Uint128" => 122_000,
        "Uint160" => 137_000,
        "Uint256" => 152_000
      }
    },
    "fheNe" => %{
      scalar: %{
        "Bool" => 23_000,
        "Uint8" => 55_000,
        "Uint16" => 55_000,
        "Uint32" => 83_000,
        "Uint64" => 84_000,
        "Uint128" => 117_000,
        "Uint160" => 117_000,
        "Uint256" => 117_000
      },
      non_scalar: %{
        "Bool" => 23_000,
        "Uint8" => 55_000,
        "Uint16" => 83_000,
        "Uint32" => 85_000,
        "Uint64" => 118_000,
        "Uint128" => 122_000,
        "Uint160" => 136_000,
        "Uint256" => 150_000
      }
    },
    "fheGe" => %{
      scalar: %{
        "Uint8" => 52_000,
        "Uint16" => 55_000,
        "Uint32" => 84_000,
        "Uint64" => 116_000,
        "Uint128" => 149_000
      },
      non_scalar: %{
        "Uint8" => 63_000,
        "Uint16" => 84_000,
        "Uint32" => 118_000,
        "Uint64" => 152_000,
        "Uint128" => 210_000
      }
    },
    "fheGt" => %{
      scalar: %{
        "Uint8" => 52_000,
        "Uint16" => 55_000,
        "Uint32" => 84_000,
        "Uint64" => 117_000,
        "Uint128" => 150_000
      },
      non_scalar: %{
        "Uint8" => 59_000,
        "Uint16" => 84_000,
        "Uint32" => 118_000,
        "Uint64" => 152_000,
        "Uint128" => 218_000
      }
    },
    "fheLe" => %{
      scalar: %{
        "Uint8" => 58_000,
        "Uint16" => 58_000,
        "Uint32" => 84_000,
        "Uint64" => 119_000,
        "Uint128" => 150_000
      },
      non_scalar: %{
        "Uint8" => 58_000,
        "Uint16" => 83_000,
        "Uint32" => 117_000,
        "Uint64" => 149_000,
        "Uint128" => 218_000
      }
    },
    "fheLt" => %{
      scalar: %{
        "Uint8" => 52_000,
        "Uint16" => 58_000,
        "Uint32" => 83_000,
        "Uint64" => 118_000,
        "Uint128" => 149_000
      },
      non_scalar: %{
        "Uint8" => 59_000,
        "Uint16" => 84_000,
        "Uint32" => 117_000,
        "Uint64" => 146_000,
        "Uint128" => 215_000
      }
    },
    "fheMin" => %{
      scalar: %{
        "Uint8" => 84_000,
        "Uint16" => 88_000,
        "Uint32" => 117_000,
        "Uint64" => 150_000,
        "Uint128" => 186_000
      },
      non_scalar: %{
        "Uint8" => 119_000,
        "Uint16" => 146_000,
        "Uint32" => 182_000,
        "Uint64" => 219_000,
        "Uint128" => 289_000
      }
    },
    "fheMax" => %{
      scalar: %{
        "Uint8" => 89_000,
        "Uint16" => 89_000,
        "Uint32" => 117_000,
        "Uint64" => 149_000,
        "Uint128" => 180_000
      },
      non_scalar: %{
        "Uint8" => 121_000,
        "Uint16" => 145_000,
        "Uint32" => 180_000,
        "Uint64" => 218_000,
        "Uint128" => 290_000
      }
    },
    "fheNeg" => %{
      types: %{
        "Uint8" => 79_000,
        "Uint16" => 93_000,
        "Uint32" => 95_000,
        "Uint64" => 131_000,
        "Uint128" => 168_000,
        "Uint256" => 269_000
      }
    },
    "fheNot" => %{
      types: %{
        "Bool" => 2,
        "Uint8" => 9,
        "Uint16" => 16,
        "Uint32" => 32,
        "Uint64" => 63,
        "Uint128" => 130,
        "Uint256" => 130
      }
    },
    "cast" => %{
      types: %{
        "Bool" => 32,
        "Uint8" => 32,
        "Uint16" => 32,
        "Uint32" => 32,
        "Uint64" => 32,
        "Uint128" => 32,
        "Uint256" => 32
      }
    },
    "trivialEncrypt" => %{
      types: %{
        "Bool" => 32,
        "Uint8" => 32,
        "Uint16" => 32,
        "Uint32" => 32,
        "Uint64" => 32,
        "Uint128" => 32,
        "Uint160" => 32,
        "Uint256" => 32
      }
    },
    "ifThenElse" => %{
      types: %{
        "Bool" => 55_000,
        "Uint8" => 55_000,
        "Uint16" => 55_000,
        "Uint32" => 55_000,
        "Uint64" => 55_000,
        "Uint128" => 57_000,
        "Uint160" => 83_000,
        "Uint256" => 108_000
      }
    },
    "fheRand" => %{
      types: %{
        "Bool" => 19_000,
        "Uint8" => 23_000,
        "Uint16" => 23_000,
        "Uint32" => 24_000,
        "Uint64" => 24_000,
        "Uint128" => 25_000,
        "Uint256" => 30_000
      }
    },
    "fheRandBounded" => %{
      types: %{
        "Uint8" => 23_000,
        "Uint16" => 23_000,
        "Uint32" => 24_000,
        "Uint64" => 24_000,
        "Uint128" => 25_000,
        "Uint256" => 30_000
      }
    }
  }

  @type_mapping %{
    # Mapping matches TypeScript ALL_FHE_TYPE_INFOS from fhevm/library-solidity/codegen/src/fheTypeInfos.ts
    0 => "Bool",
    1 => "Uint4",
    2 => "Uint8",
    3 => "Uint16",
    4 => "Uint32",
    5 => "Uint64",
    6 => "Uint128",
    7 => "Uint160",
    8 => "Uint256",
    9 => "Uint512",
    10 => "Uint1024",
    11 => "Uint2048",
    12 => "Uint2",
    13 => "Uint6",
    14 => "Uint10",
    15 => "Uint12",
    16 => "Uint14",
    17 => "Int2",
    18 => "Int4",
    19 => "Int6",
    20 => "Int8",
    21 => "Int10",
    22 => "Int12",
    23 => "Int14",
    24 => "Int16",
    25 => "Int32",
    26 => "Int64",
    27 => "Int128",
    28 => "Int160",
    29 => "Int256",
    30 => "AsciiString",
    31 => "Int512",
    32 => "Int1024",
    33 => "Int2048",
    34 => "Uint24",
    35 => "Uint40",
    36 => "Uint48",
    37 => "Uint56",
    38 => "Uint72",
    39 => "Uint80",
    40 => "Uint88",
    41 => "Uint96",
    42 => "Uint104",
    43 => "Uint112",
    44 => "Uint120",
    45 => "Uint136",
    46 => "Uint144",
    47 => "Uint152",
    48 => "Uint168",
    49 => "Uint176",
    50 => "Uint184",
    51 => "Uint192",
    52 => "Uint200",
    53 => "Uint208",
    54 => "Uint216",
    55 => "Uint224",
    56 => "Uint232",
    57 => "Uint240",
    58 => "Uint248",
    59 => "Int24",
    60 => "Int40",
    61 => "Int48",
    62 => "Int56",
    63 => "Int72",
    64 => "Int80",
    65 => "Int88",
    66 => "Int96",
    67 => "Int104",
    68 => "Int112",
    69 => "Int120",
    70 => "Int136",
    71 => "Int144",
    72 => "Int152",
    73 => "Int168",
    74 => "Int176",
    75 => "Int184",
    76 => "Int192",
    77 => "Int200",
    78 => "Int208",
    79 => "Int216",
    80 => "Int224",
    81 => "Int232",
    82 => "Int240",
    83 => "Int248"
  }

  @doc """
  Returns the HCU price for an FHE operation.

  Looks up the operation in the price table by operation name, FHE type, and
  scalar flag. Returns 0 if not found.

  ## Parameters
  - `operation_name` - Operation name (e.g. "fheAdd", "fheSub").
  - `fhe_type` - FHE type string (e.g. "Uint8", "Uint16").
  - `is_scalar` - Whether the operation is scalar (default false).

  ## Returns
  - `non_neg_integer()` - HCU cost, or 0 if unknown.
  """
  @spec get_price(String.t() | atom(), String.t() | atom(), boolean()) :: non_neg_integer()
  def get_price(operation_name, fhe_type, is_scalar \\ false) do
    case @operator_prices[operation_name] do
      %{scalar: scalar_prices, non_scalar: non_scalar_prices} ->
        prices = if is_scalar, do: scalar_prices, else: non_scalar_prices
        Map.get(prices, fhe_type, 0)

      %{scalar: scalar_prices} ->
        Map.get(scalar_prices, fhe_type, 0)

      %{types: type_prices} ->
        Map.get(type_prices, fhe_type, 0)

      _ ->
        0
    end
  end

  @doc """
  Converts a type index to its FHE type name string.

  ## Parameters
  - `type_index` - Integer type index (e.g. 1 for Uint8).

  ## Returns
  - `String.t()` - Type name (e.g. "Uint8"), or "Unknown" if not found.
  """
  @spec get_type_name(integer()) :: String.t()
  def get_type_name(type_index) when is_integer(type_index) do
    Map.get(@type_mapping, type_index, "Unknown")
  end

  @doc """
  Returns the full operator price map.

  ## Parameters
  - None.

  ## Returns
  - `map()` - Map of operation names to price structures (scalar/non_scalar).
  """
  @spec all_prices() :: map()
  def all_prices, do: @operator_prices

  @doc """
  Returns the mapping from type index to type name.

  ## Parameters
  - None.

  ## Returns
  - `%{integer() => String.t()}` - Map of type index to type name string.
  """
  @spec type_mapping() :: %{integer() => String.t()}
  def type_mapping, do: @type_mapping
end
