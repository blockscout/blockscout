defmodule ExplorerWeb.ErrorHelpersTest do
  use ExplorerWeb.ConnCase, async: true
  import Phoenix.HTML.Tag, only: [content_tag: 3]

  alias ExplorerWeb.ErrorHelpers

  @changeset %{
    errors: [
      contract_code: {"has already been taken", []}
    ]
  }

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
