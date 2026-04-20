defmodule BlockScoutWeb.API.V2.ApiViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.ApiView

  describe "render/2" do
    test "renders message.json" do
      assert %{"message" => "ok"} = ApiView.render("message.json", %{message: "ok"})
    end

    test "renders smart_contract_audit_report_changeset_errors.json" do
      changeset =
        {%{}, %{audit_report_url: :string}}
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.add_error(:audit_report_url, "can't be blank")

      result =
        ApiView.render("smart_contract_audit_report_changeset_errors.json", %{changeset: changeset})

      assert result["message"] == "Error on inserting audit report"
      assert is_map(result["errors"])
      assert map_size(result["errors"]) > 0
    end
  end
end
