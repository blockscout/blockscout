defmodule BlockScoutWeb.SmartContractViewTest do
  use ExUnit.Case

  alias BlockScoutWeb.SmartContractView

  doctest BlockScoutWeb.SmartContractView, import: true

  describe "values_with_type/1" do
    test "complex data type case" do
      value =
        {"0x9cd14677f9aa5569b3bbb351fcd67d1115aa563ae1624276d3d4e67fb3d6f926", 23_183_417, true,
         [
           {<<164, 118, 64, 69, 133, 31, 23, 170, 96, 182, 200, 232, 182, 32, 114, 190, 169, 83, 133, 33>>,
            [
              "0x0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885",
              "0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53"
            ], "0x000000000000000000000000000000000000000000000000aab260d4f14e0000"},
           {<<164, 118, 64, 69, 133, 31, 23, 170, 96, 182, 200, 232, 182, 32, 114, 190, 169, 83, 133, 33>>,
            [
              "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              "0x0000000000000000000000000000000000000000000000000000000000000000",
              "0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53"
            ], "0x000000000000000000000000000000000000000000000000aab260d4f14e0000"},
           {<<166, 139, 214, 89, 169, 22, 127, 61, 60, 1, 186, 151, 118, 161, 32, 141, 174, 143, 0, 59>>,
            [
              "0x2f9a6098d4503a127779ba975f5f6b04f842362b1809f346989e9abc0b4dedb6",
              "0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53",
              "0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f"
            ], "0x000000000000000000000000000000000000000000000000aab260d4f14e0000"},
           {<<254, 68, 107, 239, 29, 191, 122, 254, 36, 232, 30, 5, 188, 139, 39, 28, 27, 169, 165, 96>>,
            [
              "0x27333edb8bdcd40a0ae944fb121b5e2d62ea782683946654a0f5e607a908d578",
              "0x0000000000000000000000002a5fc52d8a563b2f181c6a527d422e1592c9ecfa",
              "0x000000000000000000000000a68bd659a9167f3d3c01ba9776a1208dae8f003b",
              "0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f"
            ], "0x0000000000000000000000000000000000000000000000000000000000000001"}
         ]}

      type = "tuple[bytes32,uint256,bool,tuple[address,bytes32[],bytes][]]"

      names = [
        "struct AsyncCallTest.Receipt",
        ["txHash", "blockNumber", "status", ["logs", ["from", "topics", "data"]]]
      ]

      assert SmartContractView.values_with_type(value, type, names, 0) ==
               "<div class=\"pl-3\"><i><span style=\"color: black\">struct AsyncCallTest.Receipt</span> (tuple[bytes32,uint256,bool,tuple[address,bytes32[],bytes][]])</i> : <div class=\"pl-3\"><i><span style=\"color: black\">txHash</span> (bytes32)</i> : 0x9cd14677f9aa5569b3bbb351fcd67d1115aa563ae1624276d3d4e67fb3d6f926</div><div class=\"pl-3\"><i><span style=\"color: black\">blockNumber</span> (uint256)</i> : 23183417</div><div class=\"pl-3\"><i><span style=\"color: black\">status</span> (bool)</i> : true</div><div class=\"pl-3\"><i><span style=\"color: black\">logs</span> (tuple[address,bytes32[],bytes][])</i> : [(\n<div class=\"pl-3\"><i><span style=\"color: black\">from</span> (address)</i> : 0xa4764045851f17aa60b6c8e8b62072bea9538521</div><div class=\"pl-3\"><i><span style=\"color: black\">topics</span> (bytes32[])</i> : [0x0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53]</div><div class=\"pl-3\"><i><span style=\"color: black\">data</span> (bytes)</i> : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div class=\"pl-3\"><i><span style=\"color: black\">from</span> (address)</i> : 0xa4764045851f17aa60b6c8e8b62072bea9538521</div><div class=\"pl-3\"><i><span style=\"color: black\">topics</span> (bytes32[])</i> : [0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53]</div><div class=\"pl-3\"><i><span style=\"color: black\">data</span> (bytes)</i> : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div class=\"pl-3\"><i><span style=\"color: black\">from</span> (address)</i> : 0xa68bd659a9167f3d3c01ba9776a1208dae8f003b</div><div class=\"pl-3\"><i><span style=\"color: black\">topics</span> (bytes32[])</i> : [0x2f9a6098d4503a127779ba975f5f6b04f842362b1809f346989e9abc0b4dedb6, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53, 0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f]</div><div class=\"pl-3\"><i><span style=\"color: black\">data</span> (bytes)</i> : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div class=\"pl-3\"><i><span style=\"color: black\">from</span> (address)</i> : 0xfe446bef1dbf7afe24e81e05bc8b271c1ba9a560</div><div class=\"pl-3\"><i><span style=\"color: black\">topics</span> (bytes32[])</i> : [0x27333edb8bdcd40a0ae944fb121b5e2d62ea782683946654a0f5e607a908d578, 0x0000000000000000000000002a5fc52d8a563b2f181c6a527d422e1592c9ecfa, 0x000000000000000000000000a68bd659a9167f3d3c01ba9776a1208dae8f003b, 0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f]</div><div class=\"pl-3\"><i><span style=\"color: black\">data</span> (bytes)</i> : 0x0000000000000000000000000000000000000000000000000000000000000001</div>)]</div></div>"
    end
  end
end
