defmodule Explorer.Chain.Cache.GasPriceOracleTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Cache.GasPriceOracle
  alias Explorer.Chain.Wei
  alias Explorer.Chain.Cache.Counters.AverageBlockTime

  describe "get_average_gas_price/4" do
    test "returns nil percentile values if no blocks in the DB" do
      assert {{:ok,
               %{
                 slow: nil,
                 average: nil,
                 fast: nil
               }}, []} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns nil percentile values if blocks are empty in the DB" do
      insert(:block)
      insert(:block)
      insert(:block)

      assert {{:ok,
               %{
                 slow: nil,
                 average: nil,
                 fast: nil
               }}, []} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns gas prices for blocks with failed transactions in the DB" do
      block = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")

      :transaction
      |> insert(
        error: "Reverted",
        status: :error,
        block_hash: block.hash,
        block_number: block.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 100,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      assert {{
                :ok,
                %{
                  average: %{price: 0.01},
                  fast: %{price: 0.01},
                  slow: %{price: 0.01}
                }
              }, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns nil percentile values for transactions with 0 gas price aka 'whitelisted transactions' in the DB" do
      block1 = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")
      block2 = insert(:block, number: 101, hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729")

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      assert {{:ok,
               %{
                 slow: nil,
                 average: nil,
                 fast: nil
               }}, []} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
    end

    test "returns base fee only gas estimation if there is no recent transactions with non-zero gas price" do
      block1 =
        insert(:block,
          number: 100,
          hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391",
          base_fee_per_gas: 100
        )

      block2 =
        insert(:block,
          number: 101,
          hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729",
          base_fee_per_gas: 100
        )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      assert {{:ok,
               %{
                 average: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01},
                 fast: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01},
                 slow: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01}
               }}, []} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
    end

    test "returns base fee only gas estimation with average block time if there is no recent transactions with non-zero gas price" do
      average_block_time_old_env = Application.get_env(:explorer, AverageBlockTime)

      Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)
      start_supervised!(AverageBlockTime)

      on_exit(fn ->
        Application.put_env(:explorer, AverageBlockTime, average_block_time_old_env)
      end)

      timestamp = ~U[2023-12-12 12:12:30.000000Z]

      block1 =
        insert(:block,
          number: 100,
          hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391",
          base_fee_per_gas: 100,
          timestamp: timestamp
        )

      block2 =
        insert(:block,
          number: 101,
          hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729",
          base_fee_per_gas: 100,
          timestamp: timestamp
        )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 0,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      AverageBlockTime.refresh()

      assert {{:ok,
               %{
                 average: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01, time: +0.0},
                 fast: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01, time: +0.0},
                 slow: %{base_fee: 0.01, priority_fee: +0.0, price: 0.01, time: +0.0}
               }}, []} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
    end

    test "returns the same percentile values if gas price is the same over transactions" do
      block1 = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")
      block2 = insert(:block, number: 101, hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729")

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      assert {{:ok,
               %{
                 slow: %{price: 1.0},
                 average: %{price: 1.0},
                 fast: %{price: 1.0}
               }}, _} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
    end

    test "returns correct min gas price from the block" do
      block1 = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")
      block2 = insert(:block, number: 101, hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729")

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 1,
        gas_price: 3_000_000_000,
        hash: "0x906b80861b4a0921acfbb91a7b527227b0d32adabc88bc73e8c52ff714e55016"
      )

      assert {{:ok,
               %{
                 slow: %{price: 1.0},
                 average: %{price: 2.0},
                 fast: %{price: 2.0}
               }}, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns correct average percentile" do
      block1 = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")
      block2 = insert(:block, number: 101, hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729")
      block3 = insert(:block, number: 102, hash: "0x659b2a1cc4dd1a5729900cf0c81c471d1c7891b2517bf9466f7fba56ead2fca0")

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 2_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 4_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03"
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block3.hash,
        block_number: block3.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 4_000_000_000,
        hash: "0x7d4bc5569053fc29f471901e967c9e60205ac7a122b0e9a789683652c34cc11a"
      )

      assert {{:ok,
               %{
                 average: %{price: 3.34}
               }}, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns correct gas price for EIP-1559 transactions" do
      block1 = insert(:block, number: 100, hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391")

      block2 =
        insert(:block,
          number: 101,
          hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729",
          gas_limit: Decimal.new(10_000_000),
          gas_used: Decimal.new(5_000_000),
          base_fee_per_gas: Wei.from(Decimal.new(500_000_000), :wei)
        )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269",
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03",
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 1,
        gas_price: 3_000_000_000,
        max_priority_fee_per_gas: 3_000_000_000,
        max_fee_per_gas: 3_000_000_000,
        hash: "0x906b80861b4a0921acfbb91a7b527227b0d32adabc88bc73e8c52ff714e55016",
        type: 2
      )

      assert {{:ok,
               %{
                 # including base fee
                 slow: %{price: 1.25},
                 average: %{price: 2.25}
               }}, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "return gas prices with time if available" do
      block1 =
        insert(:block,
          number: 100,
          hash: "0x3e51328bccedee581e8ba35190216a61a5d67fd91ca528f3553142c0c7d18391",
          timestamp: ~U[2023-12-12 12:12:30.000000Z]
        )

      block2 =
        insert(:block,
          number: 101,
          hash: "0x76c3da57334fffdc66c0d954dce1a910fcff13ec889a13b2d8b0b6e9440ce729",
          timestamp: ~U[2023-12-12 12:13:00.000000Z],
          gas_limit: Decimal.new(10_000_000),
          gas_used: Decimal.new(5_000_000),
          base_fee_per_gas: Wei.from(Decimal.new(500_000_000), :wei)
        )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        block_timestamp: block1.timestamp,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269",
        earliest_processing_start: ~U[2023-12-12 12:12:00.000000Z],
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        block_timestamp: block2.timestamp,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03",
        earliest_processing_start: ~U[2023-12-12 12:12:00.000000Z],
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        block_timestamp: block2.timestamp,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 1,
        gas_price: 3_000_000_000,
        max_priority_fee_per_gas: 3_000_000_000,
        max_fee_per_gas: 3_000_000_000,
        hash: "0x906b80861b4a0921acfbb91a7b527227b0d32adabc88bc73e8c52ff714e55016",
        earliest_processing_start: ~U[2023-12-12 12:12:55.000000Z],
        type: 2
      )

      assert {{
                :ok,
                %{
                  average: %{price: 2.25, time: 15000.0},
                  fast: %{price: 2.25, time: 15000.0},
                  slow: %{price: 1.25, time: 17500.0}
                }
              }, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "return gas prices with average block time if earliest_processing_start is not available" do
      average_block_time_old_env = Application.get_env(:explorer, AverageBlockTime)
      gas_price_oracle_old_env = Application.get_env(:explorer, GasPriceOracle)

      Application.put_env(:explorer, GasPriceOracle,
        safelow_time_coefficient: 2.5,
        average_time_coefficient: 1.5,
        fast_time_coefficient: 1
      )

      Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)
      start_supervised!(AverageBlockTime)

      on_exit(fn ->
        Application.put_env(:explorer, AverageBlockTime, average_block_time_old_env)
        Application.put_env(:explorer, GasPriceOracle, gas_price_oracle_old_env)
      end)

      block_number = 99_999_999
      first_timestamp = ~U[2023-12-12 12:12:30.000000Z]

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + 1 + i,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 12)
        )
      end)

      block1 =
        insert(:block,
          number: block_number + 102,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -10)
        )

      block2 =
        insert(:block,
          number: block_number + 103,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -7),
          gas_limit: Decimal.new(10_000_000),
          gas_used: Decimal.new(5_000_000),
          base_fee_per_gas: Wei.from(Decimal.new(500_000_000), :wei)
        )

      AverageBlockTime.refresh()

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0xac2a7dab94d965893199e7ee01649e2d66f0787a4c558b3118c09e80d4df8269",
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        hash: "0x5d5c2776f96704e7845f7d3c1fbba6685ab6efd6f82b6cd11d549f3b3a46bd03",
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 1,
        gas_price: 3_000_000_000,
        max_priority_fee_per_gas: 3_000_000_000,
        max_fee_per_gas: 3_000_000_000,
        hash: "0x906b80861b4a0921acfbb91a7b527227b0d32adabc88bc73e8c52ff714e55016",
        type: 2
      )

      AverageBlockTime.refresh()

      assert {{
                :ok,
                %{
                  average: %{price: 2.25, time: 1500.0},
                  fast: %{price: 2.25, time: 1000.0},
                  slow: %{price: 1.25, time: 2500.0}
                }
              }, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "does not take into account old transaction even if there is no new ones" do
      gas_price_oracle_old_env = Application.get_env(:explorer, GasPriceOracle)

      Application.put_env(:explorer, GasPriceOracle, num_of_blocks: 3)

      on_exit(fn ->
        Application.put_env(:explorer, GasPriceOracle, gas_price_oracle_old_env)
      end)

      block1 = insert(:block, number: 1)
      block2 = insert(:block, number: 2)
      block3 = insert(:block, number: 3)
      block4 = insert(:block, number: 4)
      block5 = insert(:block, number: 5)

      :transaction
      |> insert(
        status: :ok,
        block_hash: block1.hash,
        block_number: block1.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        type: 2
      )

      :transaction
      |> insert(
        status: :ok,
        block_hash: block2.hash,
        block_number: block2.number,
        cumulative_gas_used: 884_322,
        gas_used: 106_025,
        index: 0,
        gas_price: 1_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        max_fee_per_gas: 1_000_000_000,
        type: 2
      )

      :transaction
      |> build(
        status: :ok,
        block_hash: block3.hash,
        block_number: block3.number,
        gas_price: 0,
        cumulative_gas_used: 884_322
      )

      :transaction
      |> build(
        status: :ok,
        block_hash: block4.hash,
        block_number: block4.number,
        gas_price: 0,
        cumulative_gas_used: 884_322
      )

      :transaction
      |> build(
        status: :ok,
        block_hash: block5.hash,
        block_number: block5.number,
        gas_price: 0,
        cumulative_gas_used: 884_322
      )

      assert {{:ok, %{average: nil, fast: nil, slow: nil}}, _} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "does take into account EIP_1559_BASE_FEE_LOWER_BOUND_WEI env" do
      old_config = Application.get_env(:explorer, :base_fee_lower_bound)

      Application.put_env(:explorer, :base_fee_lower_bound, 1_000_000_000)

      on_exit(fn ->
        Application.put_env(:explorer, :base_fee_lower_bound, old_config)
      end)

      insert(:block,
        number: 1,
        base_fee_per_gas: Wei.from(Decimal.new(1), :gwei),
        gas_used: Decimal.new(0),
        gas_limit: Decimal.new(1000)
      )

      assert {{:ok, %{average: %{price: 1.0}, fast: %{base_fee: 1.0}, slow: %{base_fee: 1.0}}}, _} =
               GasPriceOracle.get_average_gas_price(1, 35, 60, 90)
    end

    if Application.compile_env(:explorer, :chain_type) == :celo do
      test "ignores transactions with unsupported types" do
        block =
          insert(:block,
            number: 200,
            hash: "0xfeedface00000000000000000000000000000000000000000000000000000000",
            base_fee_per_gas: nil
          )

        :transaction
        |> insert(
          status: :ok,
          block_hash: block.hash,
          block_number: block.number,
          index: 0,
          # 1 Gwei
          gas_price: 1_000_000_000,
          type: 123,
          hash: "0xcafe010000000000000000000000000000000000000000000000000000000000",
          cumulative_gas_used: 884_322,
          gas_used: 106_025
        )

        assert {{:ok,
                 %{
                   slow: nil,
                   average: nil,
                   fast: nil
                 }}, []} = GasPriceOracle.get_average_gas_price(1, 35, 60, 90)
      end
    end
  end
end
