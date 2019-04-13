defmodule BlockScoutWeb.AddressDecompiledContractViewTest do
  use Explorer.DataCase

  alias BlockScoutWeb.AddressDecompiledContractView

  describe "highlight_decompiled_code/1" do
    test "generate correct html code" do
      code = """
        [38;5;8m#
        #  eveem.org 6 Feb 2019
        #  Decompiled source of [0m0x00Bd9e214FAb74d6fC21bf1aF34261765f57e875[38;5;8m
        #
        #  Let's make the world open source
        # [0m
        [38;5;8m#
        #  I failed with these:
        [0m[38;5;8m#  - [0m[91munknowne77c646d(?)[0m[38;5;8m
        [0m[38;5;8m#  - [0m[91mtransferFromWithData(address _from, address _to, uint256 _value, bytes _data)[0m[38;5;8m
        #  All the rest is below.
        #[0m


        [38;5;8m#  Storage definitions and getters[0m

        [32mdef[0m storage:
          [32mallowance[0m is uint256 => uint256 [38;5;8m# mask(256, 0) at storage #2[0m
          [32mstor4[0m is uint256 => uint8 [38;5;8m# mask(8, 0) at storage #4[0m

        [95mdef [0mallowance(address [32m_owner[0m, address [32m_spender[0m) [95mpayable[0m: [38;5;8m[0m
          require (calldata.size - 4)[1m >= [0m64
          return [32mallowance[0m[32m[[0msha3(((320 - 1)[1m and [0m(320 - 1)[1m and [0m[32m_owner[0m), 1), ((320 - 1)[1m and [0m[32m_spender[0m[1m and [0m(320 - 1))[32m][0m


        [38;5;8m#
        #  Regular functions - see Tutorial for understanding quirks of the code
        #[0m


        [38;5;8m# folder failed in this function - may be terribly long, sorry[0m
        [95mdef [0munknownc47d033b(?) [95mpayable[0m: [38;5;8m[0m
          if (calldata.size - 4)[1m < [0m32:
              revert
          else:
              if not (320 - 1)[1m or [0mnot cd[4]:
                  revert
              else:
                  [95mmem[[0m0[95m][0m = (320 - 1)[1m and [0m(320 - 1)[1m and [0mcd[4]
                  [95mmem[[0m32[95m][0m = 4
                  [95mmem[[0m96[95m][0m = bool([32mstor4[0m[32m[[0m((320 - 1)[1m and [0m(320 - 1)[1m and [0mcd[4])[32m][0m)
                  return bool([32mstor4[0m[32m[[0m((320 - 1)[1m and [0m(320 - 1)[1m and [0mcd[4])[32m][0m)

        [95mdef [0m_fallback() [95mpayable[0m: [38;5;8m# default function[0m
          revert
      """

      result = AddressDecompiledContractView.highlight_decompiled_code(code)

      assert result ==
               "<code>  <span style=\"color:rgb(111, 110, 111)\">#</code>\n<code>  #  eveem.org 6 Feb 2019</code>\n<code>  #  Decompiled source of </span>0x00Bd9e214FAb74d6fC21bf1aF34261765f57e875<span style=\"color:rgb(111, 110, 111)\"></code>\n<code>  #</code>\n<code>  #  Let's make the world open source</code>\n<code>  # </span></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#</code>\n<code>  #  I failed with these:</code>\n<code>  </span><span style=\"color:rgb(111, 110, 111)\">#  - </span><span style=\"color:rgb(236, 89, 58)\">unknowne77c646d(?)</span><span style=\"color:rgb(111, 110, 111)\"></code>\n<code>  </span><span style=\"color:rgb(111, 110, 111)\">#  - </span><span style=\"color:rgb(236, 89, 58)\">transferFromWithData(address _from, address _to, uint256 _value, bytes _data)</span><span style=\"color:rgb(111, 110, 111)\"></code>\n<code>  #  All the rest is below.</code>\n<code>  #</span></code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#  Storage definitions and getters</span></code>\n<code></code>\n<code>  <span style=\"color:rgb(57, 115, 0)\">def</span> storage:</code>\n<code>    <span style=\"color:rgb(57, 115, 0)\">allowance</span> is uint256 => uint256 <span style=\"color:rgb(111, 110, 111)\"># mask(256, 0) at storage #2</span></code>\n<code>    <span style=\"color:rgb(57, 115, 0)\">stor4</span> is uint256 => uint8 <span style=\"color:rgb(111, 110, 111)\"># mask(8, 0) at storage #4</span></code>\n<code></code>\n<code>  <span style=\"color:rgb(136, 0, 0)\">def </span>allowance(address <span style=\"color:rgb(57, 115, 0)\">_owner</span>, address <span style=\"color:rgb(57, 115, 0)\">_spender</span>) <span style=\"color:rgb(136, 0, 0)\">payable</span>: <span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code>    require (calldata.size - 4)<span style=\"font-weight:bold\"> >= </span>64</code>\n<code>    return <span style=\"color:rgb(57, 115, 0)\">allowance</span><span style=\"color:rgb(57, 115, 0)\">[</span>sha3(((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span><span style=\"color:rgb(57, 115, 0)\">_owner</span>), 1), ((320 - 1)<span style=\"font-weight:bold\"> and </span><span style=\"color:rgb(57, 115, 0)\">_spender</span><span style=\"font-weight:bold\"> and </span>(320 - 1))<span style=\"color:rgb(57, 115, 0)\">]</span></code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#</code>\n<code>  #  Regular functions - see Tutorial for understanding quirks of the code</code>\n<code>  #</span></code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\"># folder failed in this function - may be terribly long, sorry</span></code>\n<code>  <span style=\"color:rgb(136, 0, 0)\">def </span>unknownc47d033b(?) <span style=\"color:rgb(136, 0, 0)\">payable</span>: <span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code>    if (calldata.size - 4)<span style=\"font-weight:bold\"> < </span>32:</code>\n<code>        revert</code>\n<code>    else:</code>\n<code>        if not (320 - 1)<span style=\"font-weight:bold\"> or </span>not cd[4]:</code>\n<code>            revert</code>\n<code>        else:</code>\n<code>            <span style=\"color:rgb(136, 0, 0)\">mem[</span>0<span style=\"color:rgb(136, 0, 0)\">]</span> = (320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4]</code>\n<code>            <span style=\"color:rgb(136, 0, 0)\">mem[</span>32<span style=\"color:rgb(136, 0, 0)\">]</span> = 4</code>\n<code>            <span style=\"color:rgb(136, 0, 0)\">mem[</span>96<span style=\"color:rgb(136, 0, 0)\">]</span> = bool(<span style=\"color:rgb(57, 115, 0)\">stor4</span><span style=\"color:rgb(57, 115, 0)\">[</span>((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4])<span style=\"color:rgb(57, 115, 0)\">]</span>)</code>\n<code>            return bool(<span style=\"color:rgb(57, 115, 0)\">stor4</span><span style=\"color:rgb(57, 115, 0)\">[</span>((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4])<span style=\"color:rgb(57, 115, 0)\">]</span>)</code>\n<code></code>\n<code>  <span style=\"color:rgb(136, 0, 0)\">def </span>_fallback() <span style=\"color:rgb(136, 0, 0)\">payable</span>: <span style=\"color:rgb(111, 110, 111)\"># default function</span></code>\n<code>    revert</code>\n<code></code>\n"
    end
  end

  describe "sort_contracts_by_version/1" do
    test "sorts contracts in lexicographical order" do
      contract2 = insert(:decompiled_smart_contract, decompiler_version: "v2")
      contract1 = insert(:decompiled_smart_contract, decompiler_version: "v1")
      contract3 = insert(:decompiled_smart_contract, decompiler_version: "v3")

      result = AddressDecompiledContractView.sort_contracts_by_version([contract2, contract1, contract3])

      assert result == [contract3, contract2, contract1]
    end
  end
end
