defmodule BlockScoutWeb.API.V2.AddressViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.AddressView
  alias Explorer.{Repo, TestHelper}

  test "for a proxy contract has_methods_read_proxy is true" do
    implementation_address = insert(:contract_address)
    proxy_address = insert(:contract_address) |> Repo.preload([:token])

    _proxy_smart_contract =
      insert(:smart_contract,
        address_hash: proxy_address.hash,
        contract_code_md5: "123"
      )

    insert(:proxy_implementation,
      proxy_address_hash: proxy_address.hash,
      address_hashes: [implementation_address.hash],
      names: []
    )

    TestHelper.get_eip1967_implementation_zero_addresses()

    assert AddressView.prepare_address(proxy_address)["has_methods_read_proxy"] == true
  end
end
