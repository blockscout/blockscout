# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.Proxy.MinimalProxyTest do
  use Explorer.DataCase

  alias Explorer.Chain.SmartContract.Proxy.MinimalProxy

  # Deployed bytecode from a real minimal proxy contract where the EIP-1167-like sequence
  # appears in the middle of the bytecode. Implementation address: 1e2086a7e84a32482ac03000d56925f607ccb708
  @deployed_bytecode "0x36602c57343d527f9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff593da1005b3d3d3d3d363d3d37363d731e2086a7e84a32482ac03000d56925f607ccb7085af43d3d93803e605757fd5bf3"
  @expected_impl "0x1e2086a7e84a32482ac03000d56925f607ccb708"

  describe "quick_resolve_implementations/2" do
    test "detects implementation address when pattern is in the middle of bytecode" do
      proxy_address = insert(:address, contract_code: @deployed_bytecode)
      {:ok, expected_hash} = Explorer.Chain.Hash.Address.cast(@expected_impl)

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) ==
               {:ok, [expected_hash]}
    end

    test "returns nil when pattern is absent" do
      proxy_address = insert(:address, contract_code: "0x60806040526004361061")

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) == nil
    end

    test "returns nil for nil contract code" do
      proxy_address = insert(:address, contract_code: nil)

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) == nil
    end

    test "returns nil for empty bytecode" do
      proxy_address = insert(:address, contract_code: "0x")

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) == nil
    end

    test "returns nil when bytecode exceeds 100 bytes" do
      impl_address = "AABBCCDDEE112233445566778899001122334455"
      # over 100 bytes total: 60 bytes prefix + 11 bytes pattern + 20 bytes address + suffix
      padding = String.duplicate("AA", 60)

      bytecode =
        "0x" <>
          padding <>
          "3D3D3D3D363D3D37363D73" <>
          impl_address <>
          "5AF43D3D93803E605757FD5BF3DEADBEEF"

      proxy_address = insert(:address, contract_code: bytecode)

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) == nil
    end

    test "returns nil when pattern is found but there are fewer than 20 bytes following it" do
      # pattern (11 bytes) + only 10 bytes after it — not enough for an address
      short_bytecode =
        "0x" <>
          "AABBCCDD" <>
          "3D3D3D3D363D3D37363D73" <>
          "1e2086a7e84a32482ac03000d56925f607cc"

      proxy_address = insert(:address, contract_code: short_bytecode)

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) == nil
    end

    test "correctly extracts address when pattern appears after arbitrary leading bytes" do
      impl_address = "AABBCCDDEE112233445566778899001122334455"

      bytecode =
        "0x" <>
          "DEADBEEF00112233" <>
          "3D3D3D3D363D3D37363D73" <>
          impl_address <>
          "5AF43D3D93803E605757FD5BF3"

      proxy_address = insert(:address, contract_code: bytecode)
      {:ok, expected_hash} = Explorer.Chain.Hash.Address.cast("0x" <> impl_address)

      assert MinimalProxy.quick_resolve_implementations(proxy_address, :minimal_proxy) ==
               {:ok, [expected_hash]}
    end
  end
end
