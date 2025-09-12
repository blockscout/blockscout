defmodule Explorer.Chain.SmartContract.Proxy.ERC7760Test do
  use Explorer.DataCase

  alias Explorer.Chain.SmartContract.Proxy.ERC7760
  alias Explorer.TestHelper

  @uups_basic_variant "363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3"
  @uups_i_variant "365814604357363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3"
  @beacon_basic_variant "363d3d373d3d363d602036600436635c60da1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3"
  @beacon_i_variant "363d3d373d3d363d602036600436635c60da1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3"
  @transparent_basic_variant_20_left "3d3d3373"
  @transparent_basic_variant_20_right "14605757363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b3d356020355560408036111560525736038060403d373d3d355af43d6000803e6052573d6000fd"
  @transparent_basic_variant_14_left "3d3d336d"
  @transparent_basic_variant_14_right "14605157363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e604c573d6000fd5b3d6000f35b3d3560203555604080361115604c5736038060403d373d3d355af43d6000803e604c573d6000fd"
  @transparent_i_variant_20_left "3658146083573d3d3373"
  @transparent_i_variant_20_right "14605D57363d3d37363D7f360894a13ba1A3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6058573d6000fd5b3d6000f35b3d35602035556040360380156058578060403d373d3d355af43d6000803e6058573d6000fd5b602060293d393d51543d52593df3"
  @transparent_i_variant_14_left "365814607d573d3d336d"
  @transparent_i_variant_14_right "14605757363d3D37363d7F360894A13Ba1A3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b3d35602035556040360380156052578060403d373d3d355af43d6000803e6052573d6000fd5b602060233d393d51543d52593df3"

  describe "quick_resolve_implementations/2" do
    test "returns implementation address hash for valid proxy address with uups_basic_variant" do
      proxy_address = insert(:address, contract_code: "0x" <> @uups_basic_variant)
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with uups_basic_variant and offset" do
      proxy_address = insert(:address, contract_code: "0x" <> @uups_basic_variant <> "1234")
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_basic_variant_20" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_basic_variant_20_left <>
              "1234567890123456789012345678901234567890" <> @transparent_basic_variant_20_right
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_basic_variant_20 and offset" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_basic_variant_20_left <>
              "1234567890123456789012345678901234567890" <> @transparent_basic_variant_20_right <> "1234"
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_basic_variant_14" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_basic_variant_14_left <>
              "12345678901234567890123456a8" <> @transparent_basic_variant_14_right
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_basic_variant_14 and offset" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_basic_variant_14_left <>
              "12345678901234567890123456A8" <> @transparent_basic_variant_14_right <> "1234"
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_i_variant_20" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_i_variant_20_left <>
              "1234567890123456789012345678901234567890" <> @transparent_i_variant_20_right
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_i_variant_20 and offset" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_i_variant_20_left <>
              "1234567890123456789012345678901234567890" <> @transparent_i_variant_20_right <> "1234"
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_i_variant_14" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <> @transparent_i_variant_14_left <> "1234567890123456789012341234" <> @transparent_i_variant_14_right
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with transparent_i_variant_14 and offset" do
      proxy_address =
        insert(:address,
          contract_code:
            "0x" <>
              @transparent_i_variant_14_left <>
              "1234567890123456789012341234" <> @transparent_i_variant_14_right <> "1234"
        )

      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with uups_i_variant" do
      proxy_address = insert(:address, contract_code: "0x" <> @uups_i_variant)
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with uups_i_variant and offset" do
      proxy_address = insert(:address, contract_code: "0x" <> @uups_i_variant <> "1234")
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_basic_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with beacon_basic_variant" do
      proxy_address = insert(:address, contract_code: "0x" <> @beacon_basic_variant)
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_beacon_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with beacon_basic_variant and offset" do
      proxy_address = insert(:address, contract_code: "0x" <> @beacon_basic_variant <> "1234")
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_beacon_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with beacon_i_variant" do
      proxy_address = insert(:address, contract_code: "0x" <> @beacon_i_variant)
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_beacon_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end

    test "returns implementation address hash for valid proxy address with beacon_i_variant and offset" do
      proxy_address = insert(:address, contract_code: "0x" <> @beacon_i_variant <> "1234")
      implementation_address = insert(:address)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_erc7760_beacon_requests(false, implementation_address.hash)

      assert ERC7760.quick_resolve_implementations(proxy_address) == {:ok, [implementation_address.hash]}
    end
  end
end
