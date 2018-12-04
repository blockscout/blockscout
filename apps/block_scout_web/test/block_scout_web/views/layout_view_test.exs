defmodule BlockScoutWeb.LayoutViewTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.LayoutView

  test "configured_social_media_services/0" do
    assert length(LayoutView.configured_social_media_services()) > 0
  end

  setup do
    on_exit(fn ->
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, [])
    end)
  end

  describe "network_icon_partial/0" do
    test "use the enviroment icon when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, network_icon: "custom_icon")

      assert LayoutView.network_icon_partial() == "custom_icon"
    end

    test "use the default icon when there is no env configured for it" do
      assert LayoutView.network_icon_partial() == "_network_icon.html"
    end
  end

  describe "logo/0" do
    test "use the enviroment logo when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, logo: "custom/logo.png")

      assert LayoutView.logo() == "custom/logo.png"
    end

    test "use the default logo when there is no env configured for it" do
      assert LayoutView.logo() == "/images/blockscout_logo.svg"
    end
  end

  describe "subnetwork_title/0" do
    test "use the enviroment subnetwork title when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, subnetwork: "Subnetwork Test")

      assert LayoutView.subnetwork_title() == "Subnetwork Test"
    end

    test "use the default subnetwork title when there is no env configured for it" do
      assert LayoutView.subnetwork_title() == "Sokol Testnet"
    end
  end

  describe "network_title/0" do
    test "use the enviroment network title when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, network: "Custom Network")

      assert LayoutView.network_title() == "Custom Network"
    end

    test "use the default network title when there is no env configured for it" do
      assert LayoutView.network_title() == "SPRING"
    end
  end
end
