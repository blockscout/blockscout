defmodule BlockScoutWeb.Tokens.Instance.OverviewViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.Instance.OverviewView

  describe "media_src/1" do
    test "fetches image from ['properties']['image']['description'] path" do
      json = """
        {
          "type": "object",
          "title": "TestCore Metadata",
          "properties": {
            "name": {
              "type": "string",
              "description": "Identifies the asset to which this NFT represents"
            },
            "image": {
              "type": "string",
              "description": "https://img.paoditu.com/images/cut_trace_images/6b/5f/5b754f6b5f3b5_500_500.jpg"
            },
            "description": {
              "type": "string",
              "description": "Describes the asset to which this NFT represents"
            }
          }
        }
      """

      data = Jason.decode!(json)

      assert OverviewView.media_src(%{metadata: data}) ==
               "https://img.paoditu.com/images/cut_trace_images/6b/5f/5b754f6b5f3b5_500_500.jpg"
    end

    test "handles empty images" do
      instance = %{metadata: %{"image" => ""}}

      assert OverviewView.media_src(instance) != ""
    end

    test "fetches image from image_url" do
      json = """
        {
          "name": "ManReclaimed at MetaZoo International",
          "tags": ["poap", "event"],
          "year": 2021,
          "home_url": "https://app.poap.xyz/token/98554",
          "image_url": "https://storage.googleapis.com/poapmedia/manreclaimed-at-metazoo-international-2021-logo-1615826139072.png",
          "attributes": [{
            "value": "15-Mar-2021",
            "trait_type": "startDate"
          }, {
            "value": "31-Mar-2021",
            "trait_type": "endDate"
          }, {
            "value": "true",
            "trait_type": "virtualEvent"
          }, {
            "value": "Decentraland",
            "trait_type": "city"
          }, {
            "value": "111,-23",
            "trait_type": "country"
          }, {
            "value": "https://play.decentraland.org/?position=110%2C-23&realm=loki-amber",
            "trait_type": "eventURL"
          }],
          "properties": [],
          "description": "You experienced ManReclaimed at MetaZoo International...",
          "external_url": "https://api.poap.xyz/metadata/1242/98554"
        }
      """

      data = Jason.decode!(json)

      assert OverviewView.media_src(%{metadata: data}) ==
               "https://storage.googleapis.com/poapmedia/manreclaimed-at-metazoo-international-2021-logo-1615826139072.png"
    end

    test "fetches image from animation_url" do
      json = """
        {
          "name": "Zombie MILF",
          "image": "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/a0784ea0-45be-41cd-9cdd-cc40ad20f20d-zombiepngpng.png",
          "description": "grab your crossbow, ‘cause you’re gonna turn when this MILFy zombie bites you!",
          "external_url": "https://app.cargo.build/marketplace?tokenDetail=611a876d0d14af00085bf25c:120",
          "animation_url": "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/376db72d-f8dc-44bb-b6ac-0e8a31fc6164-comp-1_8mp4.mp4",
          "cargoDisplayContent": {
            "type": "video",
            "files": ["https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/376db72d-f8dc-44bb-b6ac-0e8a31fc6164-comp-1_8mp4.mp4"]
          }
        }
      """

      data = Jason.decode!(json)

      assert OverviewView.media_src(%{metadata: data}, true) ==
               "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/376db72d-f8dc-44bb-b6ac-0e8a31fc6164-comp-1_8mp4.mp4"
    end

    test "doesn't fetch image from animation_url if high_quality_media? flag didn't passed" do
      json = """
        {
          "name": "Zombie MILF",
          "image": "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/a0784ea0-45be-41cd-9cdd-cc40ad20f20d-zombiepngpng.png",
          "description": "grab your crossbow, ‘cause you’re gonna turn when this MILFy zombie bites you!",
          "external_url": "https://app.cargo.build/marketplace?tokenDetail=611a876d0d14af00085bf25c:120",
          "animation_url": "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/376db72d-f8dc-44bb-b6ac-0e8a31fc6164-comp-1_8mp4.mp4",
          "cargoDisplayContent": {
            "type": "video",
            "files": ["https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/376db72d-f8dc-44bb-b6ac-0e8a31fc6164-comp-1_8mp4.mp4"]
          }
        }
      """

      data = Jason.decode!(json)

      assert OverviewView.media_src(%{metadata: data}) ==
               "https://assets.cargo.build/611a883b0d039100261bfe79/b89cf189-13e9-47ed-b801-a1f6aa15a7bf/a0784ea0-45be-41cd-9cdd-cc40ad20f20d-zombiepngpng.png"
    end
  end
end
