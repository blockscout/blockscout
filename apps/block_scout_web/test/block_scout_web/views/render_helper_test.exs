defmodule BlockScoutWeb.RenderHelperTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.{BlockView, RenderHelper}

  describe "render_partial/1" do
    test "renders text" do
      assert "test" == RenderHelper.render_partial("test")
    end

    test "renders the proper partial when view_module, partial and args are given" do
      block = build(:block)

      assert {:safe, _} =
               RenderHelper.render_partial(
                 view_module: BlockView,
                 partial: "_link.html",
                 block: block
               )
    end
  end
end
