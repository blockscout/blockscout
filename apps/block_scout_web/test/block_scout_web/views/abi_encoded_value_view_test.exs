defmodule BlockScoutWeb.ABIEncodedValueViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.ABIEncodedValueView

  defp value_html(type, value) do
    type
    |> ABIEncodedValueView.value_html(value)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp copy_text(type, value) do
    type
    |> ABIEncodedValueView.copy_text(value)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "value_html/2" do
    test "it formats addresses as links" do
      address = "0x0000000000000000000000000000000000000000"
      address_bytes = address |> String.trim_leading("0x") |> Base.decode16!()

      expected = ~s(<a href=\"/address/#{address}\" target=\"_blank\">#{address}</a>)

      assert value_html("address", address_bytes) == expected
    end

    test "it formats lists with newlines and spaces" do
      expected = String.trim("""
      [
        1,
        2,
        3,
        4
      ]
      """)

      assert value_html("uint[]", [1, 2, 3, 4]) == expected
    end

    test "it formats nested lists with nested depth" do
      expected = String.trim("""
      [
        [
          1,
          2
        ],
        [
          3,
          4
        ]
      ]
      """)

      assert value_html("uint[][]", [[1, 2], [3, 4]]) == expected
    end

    test "it formats lists of addresses as a list of links" do
      address = "0x0000000000000000000000000000000000000000"
      address_link = ~s(<a href=\"/address/#{address}\" target=\"_blank\">#{address}</a>)

      expected = String.trim("""
      [
        #{address_link},
        #{address_link},
        #{address_link},
        #{address_link}
      ]
      """)

      address_bytes = "0x0000000000000000000000000000000000000000" |> String.trim_leading("0x") |> Base.decode16!()

      assert value_html("address[]", [address_bytes, address_bytes, address_bytes, address_bytes]) == expected
    end
  end

  describe "copy_text/2" do
    test "it skips link formatting of addresses" do
      address = "0x0000000000000000000000000000000000000000"
      address_bytes = address |> String.trim_leading("0x") |> Base.decode16!()

      assert copy_text("address", address_bytes) == address
    end

    test "it skips the formatting when copying lists" do
      assert copy_text("uint[]", [1, 2, 3, 4]) == "[1, 2, 3, 4]"
    end
  end
end
