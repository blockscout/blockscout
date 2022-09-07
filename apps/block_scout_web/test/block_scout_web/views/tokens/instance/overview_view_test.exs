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
  end
end
