defmodule BlockScoutWeb.ViewHelpersTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.{AddressView, BlockView, ViewHelpers}

  describe "render_partial/1" do
    test "renders text" do
      assert "test" == ViewHelpers.render_partial("test")
    end

    test "renders address _link partial" do
      address = build(:address)

      assert {:safe, _} =
               ViewHelpers.render_partial(
                 view_module: AddressView,
                 partial: "_link.html",
                 address: address,
                 contract: false,
                 truncate: false
               )
    end

    test "renders address _responsive_hash partial" do
      address = build(:address)

      assert {:safe, _} =
               ViewHelpers.render_partial(
                 view_module: AddressView,
                 partial: "_responsive_hash.html",
                 address: address,
                 contract: false,
                 truncate: false
               )
    end

    test "renders block _link partial" do
      block = build(:block)

      assert {:safe, _} =
               ViewHelpers.render_partial(
                 view_module: BlockView,
                 partial: "_link.html",
                 block: block
               )
    end
  end
end
