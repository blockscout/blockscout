defmodule BlockScoutWeb.StakesHelpersTest do
  use ExUnit.Case

  alias BlockScoutWeb.StakesHelpers
  alias Timex.Duration

  test "estimated_unban_day/2" do
    block_average = Duration.from_seconds(5)

    unban_day = StakesHelpers.estimated_unban_day(10, block_average)

    now = DateTime.utc_now() |> DateTime.to_unix()
    date = DateTime.from_unix!(trunc(now + 5 * 10))
    assert Timex.format!(date, "%d %b %Y", :strftime) == unban_day
  end
end
