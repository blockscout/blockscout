defmodule Explorer.Chain.Hash.FullTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Hash

  doctest Hash.Full

  describe "cast" do
    test ~S|is not confused by big integer that starts with <<48, 120>> which is "0x"| do
      assert {:ok, _} =
               Hash.Full.cast(
                 <<48, 120, 238, 242, 122, 170, 157, 194, 106, 180, 42, 65, 178, 64, 202, 214, 148, 99, 171, 74, 64, 18,
                   14, 163, 47, 7, 39, 180, 235, 9, 98, 158>>
               )
    end
  end
end
