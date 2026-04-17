defmodule Explorer.Migrator.UnescapeAmpersandsInTokensTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{UnescapeAmpersandsInTokens, MigrationStatus}
  alias Explorer.Repo

  test "Unescapes ampersands in tokens" do
    escaped_name_token = insert(:token, name: "Rock &amp; Roll")
    escaped_symbol_token = insert(:token, symbol: "R&amp;R")
    escaped_both_token = insert(:token, name: "Tom &amp; Jerry", symbol: "T&amp;J")
    common_token = :token |> insert() |> Repo.reload()

    assert MigrationStatus.get_status("unescape_ampersands_in_tokens") == nil
    UnescapeAmpersandsInTokens.start_link([])

    Process.sleep(100)

    assert Repo.reload(escaped_name_token).name == "Rock & Roll"
    assert Repo.reload(escaped_symbol_token).symbol == "R&R"
    assert %{name: "Tom & Jerry", symbol: "T&J"} = Repo.reload(escaped_both_token)
    assert ^common_token = Repo.reload(common_token)

    assert MigrationStatus.get_status("unescape_ampersands_in_tokens") == "completed"
  end
end
