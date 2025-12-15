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
    0 => "Bool",
    1 => "Uint8",
    2 => "Uint16",
    3 => "Uint32",
    4 => "Uint64",
    5 => "Uint128",
    6 => "Uint160",
    7 => "Uint256",
    8 => "Bytes64",
    9 => "Bytes128",
    10 => "Bytes256"
  }

  @doc """
  Get HCU price for an operation.

  ## Examples
      iex> get_price("fheAdd", "Uint8", true)
      84_000

      iex> get_price("fheAdd", "Uint8", false)
      88_000
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
  Convert type index to type name.

  ## Examples
      iex> get_type_name(1)
      "Uint8"
  """
  @spec get_type_name(integer()) :: String.t()
  def get_type_name(type_index) when is_integer(type_index) do
    Map.get(@type_mapping, type_index, "Unknown")
  end

  @doc """
  Get all operator prices.
  """
  @spec all_prices() :: map()
  def all_prices, do: @operator_prices

  @doc """
  Get type mapping.
  """
  @spec type_mapping() :: %{integer() => String.t()}
  def type_mapping, do: @type_mapping
end
