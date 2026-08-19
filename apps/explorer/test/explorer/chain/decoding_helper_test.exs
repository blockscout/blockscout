# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.DecodingHelperTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Explorer.Chain.DecodingHelper

  test "value_json/2 decodes tuple components without logging a warning" do
    tuple_input = %{
      "components" => [
        %{"name" => "twitter", "type" => "string"},
        %{"name" => "telegram", "type" => "string"},
        %{"name" => "discord", "type" => "string"},
        %{"name" => "website", "type" => "string"},
        %{"name" => "farcaster", "type" => "string"}
      ],
      "name" => "socials_",
      "type" => "tuple"
    }

    log =
      capture_log(fn ->
        assert DecodingHelper.value_json(tuple_input, {"", "", "", "", ""}) == ["", "", "", "", ""]
      end)

    refute log =~ ~s(Error determining value json for "tuple")
  end
end
