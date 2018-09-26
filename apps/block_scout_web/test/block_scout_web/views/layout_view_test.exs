defmodule BlockScoutWeb.LayoutViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.LayoutView

  test "configured_social_media_services/0" do
    assert length(LayoutView.configured_social_media_services()) > 0
  end
end
