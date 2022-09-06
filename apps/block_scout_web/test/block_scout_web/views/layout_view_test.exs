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

  describe "logo/0" do
    test "use the enviroment logo when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, logo: "custom/logo.png")

      assert LayoutView.logo() == "custom/logo.png"
    end

    test "logo is nil when there is no env configured for it" do
      assert LayoutView.logo() == nil
    end
  end

  describe "subnetwork_title/0" do
    test "use the enviroment subnetwork title when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, subnetwork: "Subnetwork Test")

      assert LayoutView.subnetwork_title() == "Subnetwork Test"
    end

    test "use the default subnetwork title when there is no env configured for it" do
      assert LayoutView.subnetwork_title() == "Sokol"
    end
  end

  describe "network_title/0" do
    test "use the enviroment network title when it's configured" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Chain, network: "Custom Network")

      assert LayoutView.network_title() == "Custom Network"
    end

    test "use the default network title when there is no env configured for it" do
      assert LayoutView.network_title() == "Celo"
    end
  end

  describe "release_link/1" do
    test "set empty string if no blockscout version configured" do
      Application.put_env(:block_scout_web, :blockscout_version, nil)

      assert LayoutView.release_link(nil) == ""
    end

    test "set empty string if blockscout version is empty string" do
      Application.put_env(:block_scout_web, :blockscout_version, "")

      assert LayoutView.release_link("") == ""
    end

    test "use the default value when there is no release_link env configured for it" do
      Application.put_env(:block_scout_web, :release_link, nil)

      assert LayoutView.release_link("v1.3.4-beta") ==
               {:safe,
                ~s(<a href="https://github.com/celo-org/blockscout/releases/tag/v1.3.4-beta" class="footer-link" target="_blank">v1.3.4-beta</a>)}
    end

    test "use the default value when empty release_link env configured for it" do
      Application.put_env(:block_scout_web, :release_link, "")

      assert LayoutView.release_link("v1.3.4-beta") ==
               {:safe,
                ~s(<a href="https://github.com/celo-org/blockscout/releases/tag/v1.3.4-beta" class="footer-link" target="_blank">v1.3.4-beta</a>)}
    end

    test "use the enviroment release link when it's configured" do
      Application.put_env(
        :block_scout_web,
        :release_link,
        "https://github.com/poanetwork/blockscout/releases/tag/v1.3.4-beta"
      )

      assert LayoutView.release_link("v1.3.4-beta") ==
               {:safe,
                ~s(<a href="https://github.com/poanetwork/blockscout/releases/tag/v1.3.4-beta" class="footer-link" target="_blank">v1.3.4-beta</a>)}
    end
  end

  @supported_chains_pattern ~s([ { "title": "RSK", "url": "https://blockscout.com/rsk/mainnet", "other?": true }, { "title": "Sokol", "url": "https://blockscout.com/poa/sokol", "test_net?": true }, { "title": "POA", "url": "https://blockscout.com/poa/core" }, { "title": "LUKSO L14", "url": "https://blockscout.com/lukso/l14", "test_net?": true, "hide_in_dropdown?": true } ])

  describe "other_networks/0" do
    test "get networks list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.other_networks() == [
               %{
                 title: "POA",
                 url: "https://blockscout.com/poa/core"
               },
               %{
                 title: "RSK",
                 url: "https://blockscout.com/rsk/mainnet",
                 other?: true
               },
               %{
                 title: "LUKSO L14",
                 url: "https://blockscout.com/lukso/l14",
                 test_net?: true,
                 hide_in_dropdown?: true
               }
             ]
    end

    test "get empty networks list if SUPPORTED_CHAINS is not parsed" do
      Application.put_env(:block_scout_web, :other_networks, "not a valid json")

      assert LayoutView.other_networks() == []
    end
  end

  describe "main_nets/1" do
    test "get all main networks list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.main_nets(LayoutView.other_networks()) == [
               %{
                 title: "POA",
                 url: "https://blockscout.com/poa/core"
               },
               %{
                 title: "RSK",
                 url: "https://blockscout.com/rsk/mainnet",
                 other?: true
               }
             ]
    end
  end

  describe "test_nets/1" do
    test "get all networks list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.test_nets(LayoutView.other_networks()) == [
               %{
                 title: "LUKSO L14",
                 url: "https://blockscout.com/lukso/l14",
                 test_net?: true,
                 hide_in_dropdown?: true
               }
             ]
    end
  end

  describe "dropdown_nets/0" do
    test "get all dropdown networks list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.dropdown_nets() == [
               %{
                 title: "POA",
                 url: "https://blockscout.com/poa/core"
               },
               %{
                 title: "RSK",
                 url: "https://blockscout.com/rsk/mainnet",
                 other?: true
               }
             ]
    end
  end

  describe "dropdown_head_main_nets/0" do
    test "get dropdown all main networks except those of 'other' type list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.dropdown_head_main_nets() == [
               %{
                 title: "POA",
                 url: "https://blockscout.com/poa/core"
               }
             ]
    end
  end

  describe "dropdown_other_nets/0" do
    test "get dropdown networks of 'other' type list based on env variables" do
      Application.put_env(:block_scout_web, :other_networks, @supported_chains_pattern)

      assert LayoutView.dropdown_other_nets() == [
               %{
                 title: "RSK",
                 url: "https://blockscout.com/rsk/mainnet",
                 other?: true
               }
             ]
    end
  end
end
