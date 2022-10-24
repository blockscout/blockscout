defmodule BlockScoutWeb.AddressContractVerificationViaJsonControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.ThirdPartyIntegrations.Sourcify

  describe "sourcify integration" do
    test "parses sourcify metadata correctly" do
      data = failing_sourcify_metadata()

      %{"params_to_publish" => result} =
        Sourcify.parse_params_from_sourcify(
          "0x0E7a0c8FAb504dbB94F1e33E0A09ab4506Ea2e9b",
          data
        )

      assert result["contract_source_code"] != nil, "Contract source code should be included in params to publish"
    end
  end

  defp failing_sourcify_metadata do
    File.read!("./test/support/fixture/sourcify/cryptopunk.json")
    |> Jason.decode!()
  end
end
