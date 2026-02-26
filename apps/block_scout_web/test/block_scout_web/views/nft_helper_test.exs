defmodule BlockScoutWeb.NFTHelperTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.NFTHelper

  describe "get_media_src/2" do
    test "returns nil when metadata is nil" do
      assert NFTHelper.get_media_src(nil, true) == nil
      assert NFTHelper.get_media_src(nil, false) == nil
    end

    test "returns animation_url when present and high_quality_media? is true" do
      metadata = %{"animation_url" => "https://example.com/animation.mp4"}
      assert NFTHelper.get_media_src(metadata, true) == "https://example.com/animation.mp4"
    end

    test "falls through to image_url when animation_url is present but high_quality_media? is false" do
      metadata = %{
        "animation_url" => "https://example.com/animation.mp4",
        "image_url" => "https://example.com/image.png"
      }

      assert NFTHelper.get_media_src(metadata, false) == "https://example.com/image.png"
    end

    test "falls through to image when animation_url present, high_quality_media? false, and no image_url" do
      metadata = %{
        "animation_url" => "https://example.com/animation.mp4",
        "image" => "https://example.com/static.png"
      }

      assert NFTHelper.get_media_src(metadata, false) == "https://example.com/static.png"
    end

    test "returns image_url when present (and no animation_url or high_quality off)" do
      metadata = %{"image_url" => "https://example.com/image.png"}
      assert NFTHelper.get_media_src(metadata, true) == "https://example.com/image.png"
      assert NFTHelper.get_media_src(metadata, false) == "https://example.com/image.png"
    end

    test "returns image when present and image_url is not" do
      metadata = %{"image" => "https://example.com/fallback.png"}
      assert NFTHelper.get_media_src(metadata, true) == "https://example.com/fallback.png"
    end

    test "returns properties.image description when properties.image is a map" do
      metadata = %{
        "properties" => %{
          "image" => %{"description" => "https://example.com/props-image.png"}
        }
      }

      assert NFTHelper.get_media_src(metadata, true) == "https://example.com/props-image.png"
    end

    test "returns properties.image as string when properties.image is not a map" do
      metadata = %{
        "properties" => %{"image" => "https://example.com/props-string.png"}
      }

      assert NFTHelper.get_media_src(metadata, true) == "https://example.com/props-string.png"
    end

    test "returns nil when no image source is present" do
      metadata = %{"name" => "NFT", "description" => "No image"}
      assert NFTHelper.get_media_src(metadata, true) == nil
      assert NFTHelper.get_media_src(metadata, false) == nil
    end

    test "returns nil when result is empty string after trim" do
      metadata = %{"properties" => %{"image" => "   "}}
      assert NFTHelper.get_media_src(metadata, true) == nil
    end

    test "returns nil when properties exists but image key is missing" do
      metadata = %{"properties" => %{"name" => "something"}}
      assert NFTHelper.get_media_src(metadata, true) == nil
    end

    test "returns nil when properties is a list" do
      metadata = %{"properties" => []}
      assert NFTHelper.get_media_src(metadata, true) == nil
    end
  end

  describe "compose_resource_url/1" do
    test "transforms ipfs link like ipfs://${id}" do
      url = "ipfs://QmYFf7D2UtqnNz8Lu57Gnk3dxgdAiuboPWMEaNNjhr29tS/hidden.png"

      assert "https://ipfs.io/ipfs/QmYFf7D2UtqnNz8Lu57Gnk3dxgdAiuboPWMEaNNjhr29tS/hidden.png" ==
               NFTHelper.compose_resource_url(url)
    end

    test "transforms ipfs link like ipfs://ipfs" do
      # cspell:disable-next-line
      url = "ipfs://ipfs/Qmbgk4Ps5kiVdeYCHufMFgqzWLFuovFRtenY5P8m9vr9XW/animation.mp4"

      assert "https://ipfs.io/ipfs/Qmbgk4Ps5kiVdeYCHufMFgqzWLFuovFRtenY5P8m9vr9XW/animation.mp4" ==
               NFTHelper.compose_resource_url(url)
    end

    test "transforms ipfs link in different case" do
      url = "IpFs://baFybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json"

      assert "https://ipfs.io/ipfs/baFybeid4ed2ua7fwupv4nx2ziczr3edhygl7ws3yx6y2juon7xakgj6cfm/51.json" ==
               NFTHelper.compose_resource_url(url)
    end
  end
end
