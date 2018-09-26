defmodule BlockScoutWeb.ErrorHelpersTest do
  use BlockScoutWeb.ConnCase, async: true
  import Phoenix.HTML.Tag, only: [content_tag: 3]

  alias BlockScoutWeb.ErrorHelpers

  @changeset %{
    errors: [
      contract_code: {"has already been taken", []}
    ]
  }

  describe "error_tag tests" do
    test "error_tag/2 renders spans with default options" do
      assert ErrorHelpers.error_tag(@changeset, :contract_code) == [
               content_tag(:span, "has already been taken", class: "has-error")
             ]
    end

    test "error_tag/3 overrides default options" do
      assert ErrorHelpers.error_tag(@changeset, :contract_code, class: "something-else") == [
               content_tag(:span, "has already been taken", class: "something-else")
             ]
    end

    test "error_tag/3 merges given options with default ones" do
      assert ErrorHelpers.error_tag(@changeset, :contract_code, data_hidden: true) == [
               content_tag(:span, "has already been taken", class: "has-error", data_hidden: true)
             ]
    end
  end

  describe "translate_error/1 tests" do
    test "returns errors" do
      assert ErrorHelpers.translate_error({"test", []}) == "test"
    end

    test "returns errors with count" do
      assert ErrorHelpers.translate_error({"%{count} test", [count: 1]}) == "1 test"
    end
  end
end
