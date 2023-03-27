defmodule BlockScoutWeb.NFTHelperTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.NFTHelper

  describe "compose_ipfs_url/1" do
    test "transforms ipfs link like ipfs://${id}" do
      url = "ipfs://QmYFf7D2UtqnNz8Lu57Gnk3dxgdAiuboPWMEaNNjhr29tS/hidden.png"

      assert "https://ipfs.io/ipfs/QmYFf7D2UtqnNz8Lu57Gnk3dxgdAiuboPWMEaNNjhr29tS/hidden.png" ==
               NFTHelper.compose_ipfs_url(url)
    end

    test "transforms ipfs link like ipfs://ipfs" do
      url = "ipfs://ipfs/Qmbgk4Ps5kiVdeYCHufMFgqzWLFuovFRtenY5P8m9vr9XW/animation.mp4"

      assert "https://ipfs.io/ipfs/Qmbgk4Ps5kiVdeYCHufMFgqzWLFuovFRtenY5P8m9vr9XW/animation.mp4" ==
               NFTHelper.compose_ipfs_url(url)
    end

    test "transforms ipfs link in different case" do
      url = "IpFs://baFybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"

      assert "https://ipfs.io/ipfs/baFybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json" ==
               NFTHelper.compose_ipfs_url(url)
    end
  end
end
