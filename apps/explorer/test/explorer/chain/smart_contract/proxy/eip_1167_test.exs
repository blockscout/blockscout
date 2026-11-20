# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.Proxy.EIP1167Test do
  use Explorer.DataCase

  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.EIP1167

  @impl_address "1e2086a7e84a32482ac03000d56925f607ccb708"

  # 0xSplits modified minimal proxy (89 bytes):
  # https://github.com/0xSplits/splits-utils/blob/1ad561279084964e94a2f3d3cf75f490d2318ccf/src/LibClone.sol
  @splits_prefix "36602c57343d527f9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff593da1005b3d3d3d3d363d3d37363d73"
  @splits_suffix "5af43d3d93803e605757fd5bf3"
  @splits_bytecode "0x" <> @splits_prefix <> @impl_address <> @splits_suffix

  setup do
    {:ok, impl_hash} = Hash.Address.cast("0x" <> @impl_address)
    %{impl_hash: impl_hash}
  end

  describe "quick_resolve_implementations/2" do
    test "resolves standard EIP-1167 proxy", %{impl_hash: impl_hash} do
      proxy_address =
        insert(:address,
          contract_code: "0x363d3d373d3d3d363d73" <> @impl_address <> "5af43d82803e903d91602b57fd5bf3"
        )

      assert EIP1167.quick_resolve_implementations(proxy_address, :eip1167) == {:ok, [impl_hash]}
    end

    test "resolves 0xSplits modified minimal proxy", %{impl_hash: impl_hash} do
      proxy_address = insert(:address, contract_code: @splits_bytecode)

      assert EIP1167.quick_resolve_implementations(proxy_address, :eip1167) == {:ok, [impl_hash]}
    end

    test "does not resolve 0xSplits modified minimal proxy with trailing bytes" do
      proxy_address = insert(:address, contract_code: @splits_bytecode <> "00")

      assert EIP1167.quick_resolve_implementations(proxy_address, :eip1167) == nil
    end

    test "does not resolve 0xSplits modified minimal proxy with altered prefix" do
      # the first opcode is replaced with JUMPDEST
      "36" <> rest_of_prefix = @splits_prefix
      proxy_address = insert(:address, contract_code: "0x5b" <> rest_of_prefix <> @impl_address <> @splits_suffix)

      assert EIP1167.quick_resolve_implementations(proxy_address, :eip1167) == nil
    end

    test "does not resolve 0xSplits modified minimal proxy with altered suffix" do
      proxy_address =
        insert(:address, contract_code: "0x" <> @splits_prefix <> @impl_address <> "5af43d3d93803e605857fd5bf3")

      assert EIP1167.quick_resolve_implementations(proxy_address, :eip1167) == nil
    end
  end

  describe "proxy type resolution" do
    test "exact 0xSplits modified minimal proxy is resolved as :eip1167", %{impl_hash: impl_hash} do
      proxy_address = insert(:address, contract_code: @splits_bytecode)

      assert %{proxy_type: :eip1167, address_hashes: [^impl_hash]} =
               Proxy.try_to_get_implementation_from_known_proxy_patterns(proxy_address)
    end

    test "bytecode deviating from the 0xSplits template falls back to :minimal_proxy", %{impl_hash: impl_hash} do
      proxy_address = insert(:address, contract_code: @splits_bytecode <> "00")

      assert %{proxy_type: :minimal_proxy, address_hashes: [^impl_hash]} =
               Proxy.try_to_get_implementation_from_known_proxy_patterns(proxy_address)
    end
  end
end
