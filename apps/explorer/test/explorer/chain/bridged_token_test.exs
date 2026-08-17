# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.BridgedTokenTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.BridgedToken

  describe "decode_contract_integer_response/1" do
    test "decodes a well-formed hex-encoded integer response" do
      assert BridgedToken.decode_contract_integer_response("0x64") == 100
    end

    test "returns nil for a non-0x response" do
      assert BridgedToken.decode_contract_integer_response("garbage") == nil
    end

    test "returns nil for an empty 0x response instead of raising" do
      assert BridgedToken.decode_contract_integer_response("0x") == nil
    end

    test "returns nil for a 0x response with non-hex payload instead of raising" do
      assert BridgedToken.decode_contract_integer_response("0xzz") == nil
    end
  end
end
