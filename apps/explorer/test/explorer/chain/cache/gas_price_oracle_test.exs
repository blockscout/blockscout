defmodule Explorer.Chain.Cache.GasPriceOracleTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.GasPriceOracle
  alias Explorer.Repo

  describe "get_average_gas_price/4" do
    test "returns nil percentile values if no blocks in the DB" do
      assert {:ok,
              %{
                "slow" => nil,
                "average" => nil,
                "fast" => nil
              }} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns nil percentile values if blocks are empty in the DB" do
      insert(:block)
      insert(:block)
      insert(:block)

      assert {:ok,
              %{
                "slow" => nil,
                "average" => nil,
                "fast" => nil
              }} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end

    test "returns nil percentile values for blocks with failed txs in the DB" do
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

      assert {:ok,
              %{
                "slow" => nil,
                "average" => nil,
                "fast" => nil
              }} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
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

      assert {:ok,
              %{
                "slow" => nil,
                "average" => nil,
                "fast" => nil
              }} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
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

      assert {:ok,
              %{
                "slow" => 1.0,
                "average" => 1.0,
                "fast" => 1.0
              }} = GasPriceOracle.get_average_gas_price(2, 35, 60, 90)
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

      assert {:ok,
              %{
                "slow" => 1.0,
                "average" => 1.0,
                "fast" => 1.0
              }} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
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

      assert {:ok,
              %{
                "average" => 4.0
              }} = GasPriceOracle.get_average_gas_price(3, 35, 60, 90)
    end
  end
end
