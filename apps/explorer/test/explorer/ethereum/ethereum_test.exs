defmodule Explorer.EthereumTest do
  use Explorer.DataCase

  alias Explorer.Ethereum

  describe "decode_integer_field/1" do
    test "returns the integer value of a hex value" do
      assert(Ethereum.decode_integer_field("0x7f2fb") == 520_955)
    end
  end

  describe "decode_time_field/1" do
    test "returns the date value of a hex value" do
      the_seventies = Timex.parse!("1970-01-01T00:00:18-00:00", "{ISO:Extended}")
      assert(Ethereum.decode_time_field("0x12") == the_seventies)
    end
  end
end
