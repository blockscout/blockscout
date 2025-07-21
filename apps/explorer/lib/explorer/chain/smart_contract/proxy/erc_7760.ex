defmodule Explorer.Chain.SmartContract.Proxy.ERC7760 do
  @moduledoc """
  Module for fetching proxy implementation from https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7760.md
  """

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy.EIP1967

  @transparent_basic_variant_20_left <<0x3D3D3373::4-unit(8)>>
  @transparent_basic_variant_20_right <<0x14605757363D3D37363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E6052573D6000FD5B3D6000F35B3D356020355560408036111560525736038060403D373D3D355AF43D6000803E6052573D6000FD::824>>
  @transparent_basic_variant_14_left <<0x3D3D336D::4-unit(8)>>
  @transparent_basic_variant_14_right <<0x14605157363D3D37363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E604C573D6000FD5B3D6000F35B3D3560203555604080361115604C5736038060403D373D3D355AF43D6000803E604C573D6000FD::824>>
  @transparent_i_variant_20_left <<0x3658146083573D3D3373::10-unit(8)>>
  @transparent_i_variant_20_right <<0x14605D57363D3D37363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E6058573D6000FD5B3D6000F35B3D35602035556040360380156058578060403D373D3D355AF43D6000803E6058573D6000FD5B602060293D393D51543D52593DF3::928>>
  @transparent_i_variant_14_left <<0x365814607D573D3D336D::10-unit(8)>>
  @transparent_i_variant_14_right <<0x14605757363D3D37363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E6052573D6000FD5B3D6000F35B3D35602035556040360380156052578060403D373D3D355AF43D6000803E6052573D6000FD5B602060233D393D51543D52593DF3::928>>
  @uups_basic_variant <<0x363D3D373D3D363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E6038573D6000FD5B3D6000F3::488>>
  @uups_i_variant <<0x365814604357363D3D373D3D363D7F360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC545AF43D6000803E603E573D6000FD5B3D6000F35B6020600F3D393D51543D52593DF3::656>>
  @beacon_basic_variant <<0x363D3D373D3D363D602036600436635C60DA1B60E01B36527FA3F0AD74E5423AEBFD80D3EF4346578335A9A72AEAEE59FF6CB3582B35133D50545AFA5036515AF43D6000803E604D573D6000FD5B3D6000F3::656>>
  @beacon_i_variant <<0x363D3D373D3D363D602036600436635C60DA1B60E01B36527FA3F0AD74E5423AEBFD80D3EF4346578335A9A72AEAEE59FF6CB3582B35133D50545AFA361460525736515AF43D600060013E6052573D6001FD5B3D6001F3::696>>

  @doc """
  Get implementation address hash following ERC-7760.
  """
  @spec match_bytecode_and_resolve_implementation(Address.t()) :: Hash.Address.t() | :error | nil
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def match_bytecode_and_resolve_implementation(proxy_address) do
    result =
      case proxy_address.contract_code && proxy_address.contract_code.bytes do
        <<@transparent_basic_variant_20_left, _::20-bytes, @transparent_basic_variant_20_right, _::binary>> ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        <<@transparent_basic_variant_14_left, _::14-bytes, @transparent_basic_variant_14_right, _::binary>> ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        <<@transparent_i_variant_20_left, _::20-bytes, @transparent_i_variant_20_right, _::binary>> ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        <<@transparent_i_variant_14_left, _::14-bytes, @transparent_i_variant_14_right, _::binary>> ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        @uups_basic_variant <> _ ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        @uups_i_variant <> _ ->
          EIP1967.resolve_implementations(proxy_address, :eip1967)

        @beacon_basic_variant <> _ ->
          EIP1967.resolve_implementations(proxy_address, :eip1967_beacon)

        @beacon_i_variant <> _ ->
          EIP1967.resolve_implementations(proxy_address, :eip1967_beacon)

        _ ->
          nil
      end

    case result do
      [implementation_address_hash] ->
        implementation_address_hash

      result ->
        result
    end
  end
end
