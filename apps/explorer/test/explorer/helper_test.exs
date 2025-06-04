defmodule Explorer.HelperTest do
  use ExUnit.Case
  alias Explorer.Helper
  alias Explorer.Chain.Data

  describe "decode_data/2" do
    test "decodes 0x starting bytes" do
      data = "0x3078f11400000000000000000000000000000000000000000000000000000000"
      types = [{:uint, 32}]

      assert [21_924_702_239_838_702_630_355_123_058_721_243_447_914_074_382_437_861_546_344_133_536_048_966_795_264] ==
               Helper.decode_data(data, types)
    end

    test "decodes 0x starting bytes with %Data{} struct" do
      data = %Data{
        bytes: <<48, 120, 241, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      }

      types = [{:uint, 32}]

      assert [21_924_702_239_838_702_630_355_123_058_721_243_447_914_074_382_437_861_546_344_133_536_048_966_795_264] ==
               Helper.decode_data(data, types)
    end
  end
end
