defmodule Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArgumentsTest do
  use Explorer.DataCase

  alias Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments

  # Test address hex (20 bytes = 40 hex chars)
  @test_impl_address "1234567890123456789012345678901234567890"
  @test_impl_address_2 "AABBCCDDEE11223344556677889900112233AABB"

  describe "quick_resolve_implementations/2 with wighawag variant" do
    test "returns implementation address hash for valid wighawag proxy address" do
      # wighawag variant bytecode pattern
      # 0x3D3D3D3D363D3D3761 (9 bytes) + 2 bytes + 0x603736393661 (6 bytes) + 2 bytes + 0x013D73 (3 bytes) + implementation address (20 bytes) + rest
      bytecode =
        "0x3D3D3D3D363D3D3761" <>
          "AABB" <>
          "603736393661" <>
          "CCDD" <>
          "013D73" <>
          @test_impl_address <>
          "5AF43D82803E903D91602B57FD5BF3"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, impl_hash} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash]}
    end

    test "returns implementation address hash for valid wighawag proxy with additional bytecode" do
      bytecode =
        "0x3D3D3D3D363D3D3761" <>
          "AABB" <>
          "603736393661" <>
          "CCDD" <>
          "013D73" <>
          @test_impl_address <>
          "5AF43D82803E903D91602B57FD5BF3" <>
          "DEADBEEF" <>
          "1234567890"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, impl_hash} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash]}
    end

    test "returns nil for invalid wighawag proxy address" do
      proxy_address = insert(:address, contract_code: "0x60806040")

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end

    test "returns nil for proxy address without contract code" do
      proxy_address = insert(:address, contract_code: nil)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end
  end

  describe "quick_resolve_implementations/2 with solady variant" do
    test "returns implementation address hash for valid solady proxy address" do
      # solady variant bytecode pattern
      # 0x363d3d373d3d3d363d73 (10 bytes) + implementation address (20 bytes) + 0x5af43d3d93803e602a57fd5bf3 (13 bytes) + rest
      bytecode =
        "0x363d3d373d3d3d363d73" <>
          @test_impl_address <>
          "5af43d3d93803e602a57fd5bf3"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, impl_hash} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash]}
    end

    test "returns implementation address hash for valid solady proxy with immutable arguments" do
      bytecode =
        "0x363d3d373d3d3d363d73" <>
          @test_impl_address <>
          "5af43d3d93803e602a57fd5bf3" <>
          "AABBCCDDEE11223344556677" <>
          "8899"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, impl_hash} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash]}
    end

    test "returns implementation address hash for valid solady proxy with additional bytecode prefix" do
      # Note: Solady pattern is found anywhere in bytecode, so prefix doesn't matter for matching
      bytecode =
        "0x363d3d373d3d3d363d73" <>
          @test_impl_address <>
          "5af43d3d93803e602a57fd5bf3"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, impl_hash} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash]}
    end

    test "returns nil for invalid solady proxy address" do
      proxy_address = insert(:address, contract_code: "0x60806040")

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end
  end

  describe "quick_resolve_implementations/2 edge cases" do
    test "returns nil for empty contract code" do
      proxy_address = insert(:address, contract_code: "0x")

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end

    test "returns nil for bytecode matching wighawag prefix but too short" do
      proxy_address = insert(:address, contract_code: "0x3D3D3D3D363D3D3761AABB")

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end

    test "returns nil for bytecode matching solady prefix but too short" do
      proxy_address = insert(:address, contract_code: "0x363d3d373d3d3d363d73")

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end

    test "returns nil for nil contract_code in proxy_address" do
      proxy_address = insert(:address, contract_code: nil)

      assert CloneWithImmutableArguments.quick_resolve_implementations(proxy_address, :clone_with_immutable_arguments) ==
               nil
    end

    test "correctly distinguishes between wighawag and solady variants" do
      # Wighawag variant
      wighawag_bytecode =
        "0x3D3D3D3D363D3D3761" <>
          "AABB" <>
          "603736393661" <>
          "CCDD" <>
          "013D73" <>
          @test_impl_address <>
          "5AF43D82803E903D91602B57FD5BF3"

      wighawag_proxy = insert(:address, contract_code: wighawag_bytecode)

      # Solady variant - use different address for distinction
      solady_bytecode =
        "0x363d3d373d3d3d363d73" <>
          @test_impl_address_2 <>
          "5af43d3d93803e602a57fd5bf3"

      solady_proxy = insert(:address, contract_code: solady_bytecode)

      {:ok, impl_hash_1} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address)
      {:ok, impl_hash_2} = Explorer.Chain.Hash.Address.cast("0x" <> @test_impl_address_2)

      assert CloneWithImmutableArguments.quick_resolve_implementations(wighawag_proxy, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash_1]}

      assert CloneWithImmutableArguments.quick_resolve_implementations(solady_proxy, :clone_with_immutable_arguments) ==
               {:ok, [impl_hash_2]}
    end
  end
end
