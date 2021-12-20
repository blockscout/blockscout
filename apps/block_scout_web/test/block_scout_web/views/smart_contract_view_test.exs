defmodule BlockScoutWeb.SmartContractViewTest do
  use ExUnit.Case

  alias BlockScoutWeb.SmartContractView

  doctest BlockScoutWeb.SmartContractView, import: true

  describe "values_with_type/1" do
    test "complex data type case" do
      value =
        {<<156, 209, 70, 119, 249, 170, 85, 105, 179, 187, 179, 81, 252, 214, 125, 17, 21, 170, 86, 58, 225, 98, 66,
           118, 211, 212, 230, 127, 179, 214, 249, 38>>, 23_183_417, true,
         [
           {<<164, 118, 64, 69, 133, 31, 23, 170, 96, 182, 200, 232, 182, 32, 114, 190, 169, 83, 133, 33>>,
            [
              <<15, 103, 152, 165, 96, 121, 58, 84, 195, 188, 254, 134, 169, 60, 222, 30, 115, 8, 125, 148, 76, 14, 162,
                5, 68, 19, 125, 65, 33, 57, 104, 133>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 191, 61, 111, 131, 12, 226, 99, 202, 233, 135, 25, 57, 130, 25, 44,
                217, 144, 68, 43, 83>>
            ],
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 170, 178, 96, 212, 241, 78, 0, 0>>},
           {<<164, 118, 64, 69, 133, 31, 23, 170, 96, 182, 200, 232, 182, 32, 114, 190, 169, 83, 133, 33>>,
            [
              <<221, 242, 82, 173, 27, 226, 200, 155, 105, 194, 176, 104, 252, 55, 141, 170, 149, 43, 167, 241, 99, 196,
                161, 22, 40, 245, 90, 77, 245, 35, 179, 239>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 191, 61, 111, 131, 12, 226, 99, 202, 233, 135, 25, 57, 130, 25, 44,
                217, 144, 68, 43, 83>>
            ],
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 170, 178, 96, 212, 241, 78, 0, 0>>},
           {<<166, 139, 214, 89, 169, 22, 127, 61, 60, 1, 186, 151, 118, 161, 32, 141, 174, 143, 0, 59>>,
            [
              <<47, 154, 96, 152, 212, 80, 58, 18, 119, 121, 186, 151, 95, 95, 107, 4, 248, 66, 54, 43, 24, 9, 243, 70,
                152, 158, 154, 188, 11, 77, 237, 182>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 191, 61, 111, 131, 12, 226, 99, 202, 233, 135, 25, 57, 130, 25, 44,
                217, 144, 68, 43, 83>>,
              <<0, 5, 0, 0, 36, 155, 252, 47, 60, 200, 214, 143, 107, 107, 247, 35, 14, 160, 168, 237, 133, 61, 231, 49,
                0, 0, 0, 0, 0, 0, 2, 79>>
            ],
            <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 170, 178, 96, 212, 241, 78, 0, 0>>},
           {<<254, 68, 107, 239, 29, 191, 122, 254, 36, 232, 30, 5, 188, 139, 39, 28, 27, 169, 165, 96>>,
            [
              <<39, 51, 62, 219, 139, 220, 212, 10, 10, 233, 68, 251, 18, 27, 94, 45, 98, 234, 120, 38, 131, 148, 102,
                84, 160, 245, 230, 7, 169, 8, 213, 120>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42, 95, 197, 45, 138, 86, 59, 47, 24, 28, 106, 82, 125, 66, 46, 21,
                146, 201, 236, 250>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 166, 139, 214, 89, 169, 22, 127, 61, 60, 1, 186, 151, 118, 161, 32,
                141, 174, 143, 0, 59>>,
              <<0, 5, 0, 0, 36, 155, 252, 47, 60, 200, 214, 143, 107, 107, 247, 35, 14, 160, 168, 237, 133, 61, 231, 49,
                0, 0, 0, 0, 0, 0, 2, 79>>
            ], <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>}
         ]}

      type = "tuple[bytes32,uint256,bool,tuple[address,bytes32[],bytes][]]"

      names = [
        "struct AsyncCallTest.Receipt",
        ["txHash", "blockNumber", "status", ["logs", ["from", "topics", "data"]]]
      ]

      assert SmartContractView.values_with_type(value, type, names, 0) ==
               "<div style=\"padding-left: 20px\"><span style=\"color: black\">struct AsyncCallTest.Receipt</span> (tuple[bytes32,uint256,bool,tuple[address,bytes32[],bytes][]]) : <div style=\"padding-left: 20px\"><span style=\"color: black\">txHash</span> (bytes32) : 0x9cd14677f9aa5569b3bbb351fcd67d1115aa563ae1624276d3d4e67fb3d6f926</div><div style=\"padding-left: 20px\"><span style=\"color: black\">blockNumber</span> (uint256) : 23183417</div><div style=\"padding-left: 20px\"><span style=\"color: black\">status</span> (bool) : true</div><div style=\"padding-left: 20px\"><span style=\"color: black\">logs</span> (tuple[address,bytes32[],bytes][]) : [(\n<div style=\"padding-left: 20px\"><span style=\"color: black\">from</span> (address) : 0xa4764045851f17aa60b6c8e8b62072bea9538521</div><div style=\"padding-left: 20px\"><span style=\"color: black\">topics</span> (bytes32[]) : [0x0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53]</div><div style=\"padding-left: 20px\"><span style=\"color: black\">data</span> (bytes) : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div style=\"padding-left: 20px\"><span style=\"color: black\">from</span> (address) : 0xa4764045851f17aa60b6c8e8b62072bea9538521</div><div style=\"padding-left: 20px\"><span style=\"color: black\">topics</span> (bytes32[]) : [0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53]</div><div style=\"padding-left: 20px\"><span style=\"color: black\">data</span> (bytes) : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div style=\"padding-left: 20px\"><span style=\"color: black\">from</span> (address) : 0xa68bd659a9167f3d3c01ba9776a1208dae8f003b</div><div style=\"padding-left: 20px\"><span style=\"color: black\">topics</span> (bytes32[]) : [0x2f9a6098d4503a127779ba975f5f6b04f842362b1809f346989e9abc0b4dedb6, 0x000000000000000000000000bf3d6f830ce263cae987193982192cd990442b53, 0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f]</div><div style=\"padding-left: 20px\"><span style=\"color: black\">data</span> (bytes) : 0x000000000000000000000000000000000000000000000000aab260d4f14e0000</div>),\n(<div style=\"padding-left: 20px\"><span style=\"color: black\">from</span> (address) : 0xfe446bef1dbf7afe24e81e05bc8b271c1ba9a560</div><div style=\"padding-left: 20px\"><span style=\"color: black\">topics</span> (bytes32[]) : [0x27333edb8bdcd40a0ae944fb121b5e2d62ea782683946654a0f5e607a908d578, 0x0000000000000000000000002a5fc52d8a563b2f181c6a527d422e1592c9ecfa, 0x000000000000000000000000a68bd659a9167f3d3c01ba9776a1208dae8f003b, 0x00050000249bfc2f3cc8d68f6b6bf7230ea0a8ed853de731000000000000024f]</div><div style=\"padding-left: 20px\"><span style=\"color: black\">data</span> (bytes) : 0x0000000000000000000000000000000000000000000000000000000000000001</div>)]</div></div>"
    end
  end
end
