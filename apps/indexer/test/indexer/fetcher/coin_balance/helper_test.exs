# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.HelperTest do
  use ExUnit.Case, async: true

  alias Indexer.Fetcher.CoinBalance.Helper

  describe "reduce_daily_params_to_max_value/1" do
    test "keeps the greatest value per address and day" do
      address_a = "0x0000000000000000000000000000000000000001"
      address_b = "0x0000000000000000000000000000000000000002"

      params = [
        %{address_hash: address_a, day: ~D[2026-11-16], value: 3},
        %{address_hash: address_a, day: ~D[2026-11-17], value: 5},
        %{address_hash: address_a, day: ~D[2026-11-17], value: 20},
        %{address_hash: address_a, day: ~D[2026-11-17], value: 7},
        %{address_hash: address_b, day: ~D[2026-11-17], value: 1},
        %{address_hash: address_b, day: ~D[2026-11-17], value: 1}
      ]

      assert params |> Helper.reduce_daily_params_to_max_value() |> Enum.sort() ==
               Enum.sort([
                 %{address_hash: address_a, day: ~D[2026-11-16], value: 3},
                 %{address_hash: address_a, day: ~D[2026-11-17], value: 20},
                 %{address_hash: address_b, day: ~D[2026-11-17], value: 1}
               ])
    end

    test "passes entries with unresolved day through" do
      param = %{address_hash: "0x0000000000000000000000000000000000000001", day: ~D[2026-11-17], value: 1}

      assert Helper.reduce_daily_params_to_max_value([nil, param, nil]) == [nil, nil, param]
      assert Helper.reduce_daily_params_to_max_value([]) == []
    end
  end
end
