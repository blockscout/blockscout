defmodule BlockScoutWeb.RenderHelpersTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.{BlockView, RenderHelpers}

  describe "render_partial/1" do
    test "renders text" do
      assert "test" == RenderHelpers.render_partial("test")
    end

    test "renders the proper partial when view_module, partial and args are given" do
      block = build(:block)

      assert {:safe, _} =
               RenderHelpers.render_partial(
                 view_module: BlockView,
                 partial: "_link.html",
                 block: block
               )
    end
  end
end
