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
               "<code>  <span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  eveem.org 6 Feb 2019</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  Decompiled source of </span>0x00Bd9e214FAb74d6fC21bf1aF34261765f57e875<span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  Let's make the world open source</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  # </span></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  I failed with these:</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  </span><span style=\"color:rgb(111, 110, 111)\">#  - </span>unknowne77c646d(?)<span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  </span><span style=\"color:rgb(111, 110, 111)\">#  - </span>transferFromWithData(address _from, address _to, uint256 _value, bytes _data)<span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  All the rest is below.</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #</span></code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#  Storage definitions and getters</span></code>\n<code></code>\n<code>  <span class=\"hljs-keyword\">def</span> storage:</code>\n<code>    allowance is <span class=\"hljs-keyword\">uint</span>256 => <span class=\"hljs-keyword\">uint</span>256 <span style=\"color:rgb(111, 110, 111)\"># mask(256, 0) at storage #2</span></code>\n<code>    stor4 is <span class=\"hljs-keyword\">uint</span>256 => <span class=\"hljs-keyword\">uint</span>8 <span style=\"color:rgb(111, 110, 111)\"># mask(8, 0) at storage #4</span></code>\n<code></code>\n<code>  <span class=\"hljs-keyword\">def</span> allowance(<span class=\"hljs-keyword\">address</span> _owner, <span class=\"hljs-keyword\">address</span> _spender) <span class=\"hljs-title\">payable</span>: </code>\n<code>    <span class=\"hljs-keyword\">require</span> (calldata.size - 4)<span style=\"font-weight:bold\"> >= </span>64</code>\n<code>    <span class=\"hljs-keyword\">return</span> allowance[sha3(((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>_owner), 1), ((320 - 1)<span style=\"font-weight:bold\"> and </span>_spender<span style=\"font-weight:bold\"> and </span>(320 - 1))]</code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  Regular functions - see Tutorial for understanding quirks of the code</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #</span></code>\n<code></code>\n<code></code>\n<code>  <span style=\"color:rgb(111, 110, 111)\"># folder failed in this function - may be terribly long, sorry</span></code>\n<code>  <span class=\"hljs-keyword\">def</span> unknownc47d033b(?) <span class=\"hljs-title\">payable</span>: </code>\n<code>    if (calldata.size - 4)<span style=\"font-weight:bold\"> < </span>32:</code>\n<code>        <span class=\"hljs-keyword\">revert</span></code>\n<code>    else:</code>\n<code>        if not (320 - 1)<span style=\"font-weight:bold\"> or </span>not cd[4]:</code>\n<code>            <span class=\"hljs-keyword\">revert</span></code>\n<code>        else:</code>\n<code>            <span class=\"hljs-keyword\">mem</span>[0] = (320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4]</code>\n<code>            <span class=\"hljs-keyword\">mem</span>[32] = 4</code>\n<code>            <span class=\"hljs-keyword\">mem</span>[96] = <span class=\"hljs-keyword\">bool</span>(stor4[((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4])])</code>\n<code>            <span class=\"hljs-keyword\">return</span> <span class=\"hljs-keyword\">bool</span>(stor4[((320 - 1)<span style=\"font-weight:bold\"> and </span>(320 - 1)<span style=\"font-weight:bold\"> and </span>cd[4])])</code>\n<code></code>\n<code>  <span class=\"hljs-keyword\">def</span> _fallback() <span class=\"hljs-title\">payable</span>: <span style=\"color:rgb(111, 110, 111)\"># default function</span></code>\n<code>    <span class=\"hljs-keyword\">revert</span></code>\n<code></code>\n<code></code>\n"
    end

    test "adds style span to every line" do
      code = """
        [38;5;8m#
        #  eveem.org 6 Feb 2019
        #  Decompiled source of [0m0x00Bd9e214FAb74d6fC21bf1aF34261765f57e875[38;5;8m
        #
        #  Let's make the world open source
        # [0m
      """

      assert AddressDecompiledContractView.highlight_decompiled_code(code) ==
               "<code>  <span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  eveem.org 6 Feb 2019</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  Decompiled source of </span>0x00Bd9e214FAb74d6fC21bf1aF34261765f57e875<span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  #  Let's make the world open source</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">  # </span></code>\n<code></code>\n<code></code>\n"
    end

    test "does not remove bold text" do
      code = """
      [38;5;8m#
      #  Eveem.org 26 Apr 2019
      #  Decompiled source of [0m[92m0x06012c8cf97bead5deae237070f9587f8e7a266d[0m[38;5;8m
      #
      #  Let's make the world open source
      # [0m

      [95mconst [0mname = [1m'CryptoKitties'[0m
      [95mconst [0msymbol = [1m'CK'[0m
      [95mconst [0mGEN0_STARTING_PRICE = [1m10^16[0m
      [95mconst [0mGEN0_AUCTION_DURATION = [1m(24 * 3600)[0m
      [95mconst [0mGEN0_CREATION_LIMIT = [1m45000[0m
      [95mconst [0mPROMO_CREATION_LIMIT = [1m5000[0m

      """

      assert AddressDecompiledContractView.highlight_decompiled_code(code) ==
               "<code><span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">#  Eveem.org 26 Apr 2019</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">#  Decompiled source of </span>0x06012c8cf97bead5deae237070f9587f8e7a266d<span style=\"color:rgb(111, 110, 111)\"></span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">#</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\">#  Let's make the world open source</span></code>\n<code><span style=\"color:rgb(111, 110, 111)\"># </span></code>\n<code></code>\n<code>const name = <span style=\"font-weight:bold\">'CryptoKitties'</span></code>\n<code>const symbol = <span style=\"font-weight:bold\">'CK'</span></code>\n<code>const GEN0_STARTING_PRICE = <span style=\"font-weight:bold\">10^16</span></code>\n<code>const GEN0_AUCTION_DURATION = <span style=\"font-weight:bold\">(24 * 3600)</span></code>\n<code>const GEN0_CREATION_LIMIT = <span style=\"font-weight:bold\">45000</span></code>\n<code>const PROMO_CREATION_LIMIT = <span style=\"font-weight:bold\">5000</span></code>\n<code></code>\n<code></code>\n<code></code>\n"
    end
  end

  describe "last_decompiled_contract_version/1" do
    test "returns last version" do
      contract2 = insert(:decompiled_smart_contract, decompiler_version: "v2")
      contract1 = insert(:decompiled_smart_contract, decompiler_version: "v1")
      contract3 = insert(:decompiled_smart_contract, decompiler_version: "v3")

      result = AddressDecompiledContractView.last_decompiled_contract_version([contract2, contract1, contract3])

      assert result == contract3
    end
  end
end
