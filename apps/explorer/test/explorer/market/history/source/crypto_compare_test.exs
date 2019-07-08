defmodule Explorer.Market.History.Source.CryptoCompareTest do
  use ExUnit.Case, async: false

  alias Explorer.Market.History.Source.CryptoCompare
  alias Plug.Conn

  @json """
  {
    "Response": "Success",
    "Type": 100,
    "Aggregated": false,
    "Data": [
      {
        "time": 1524528000,
        "close": 9655.77,
        "high": 9741.91,
        "low": 8957.68,
        "open": 8967.86,
        "volumefrom": 136352.05,
        "volumeto": 1276464750.74
      },
      {
        "time": 1524614400,
        "close": 8873.62,
        "high": 9765.23,
        "low": 8757.06,
        "open": 9657.69,
        "volumefrom": 192797.41,
        "volumeto": 1779806222.98
      },
      {
        "time": 1524700800,
        "close": 8804.32,
        "high": 8965.84,
        "low": 8669.38,
        "open": 8873.57,
        "volumefrom": 74704.5,
        "volumeto": 661168891
      }
    ],
    "TimeTo": 1524700800,
    "TimeFrom": 1523836800,
    "FirstValueInArray": true,
    "ConversionType": {
      "type": "direct",
      "conversionSymbol": ""
    }
  }
  """

  describe "fetch_history/1" do
    setup do
      bypass = Bypass.open()
      Application.put_env(:explorer, CryptoCompare, base_url: "http://localhost:#{bypass.port}")

      {:ok, bypass: bypass}
    end

    test "with successful request", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, @json) end)

      expected = [
        %{
          closing_price: Decimal.from_float(9655.77),
          date: ~D[2018-04-24],
          opening_price: Decimal.from_float(8967.86)
        },
        %{
          closing_price: Decimal.from_float(8873.62),
          date: ~D[2018-04-25],
          opening_price: Decimal.from_float(9657.69)
        },
        %{
          closing_price: Decimal.from_float(8804.32),
          date: ~D[2018-04-26],
          opening_price: Decimal.from_float(8873.57)
        }
      ]

      assert {:ok, expected} == CryptoCompare.fetch_history(3)
    end

    test "with errored request", %{bypass: bypass} do
      error_text = ~S({"error": "server error"})
      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 500, error_text) end)

      assert :error == CryptoCompare.fetch_history(3)
    end

    test "rejects empty prices", %{bypass: bypass} do
      json = """
      {
        "Response": "Success",
        "Type": 100,
        "Aggregated": false,
        "Data": [
          {
            "time": 1524528000,
            "close": 0,
            "high": 9741.91,
            "low": 8957.68,
            "open": 0,
            "volumefrom": 136352.05,
            "volumeto": 1276464750.74
          },
          {
            "time": 1524614400,
            "close": 0,
            "high": 9765.23,
            "low": 8757.06,
            "open": 0,
            "volumefrom": 192797.41,
            "volumeto": 1779806222.98
          },
          {
            "time": 1524700800,
            "close": 8804.32,
            "high": 8965.84,
            "low": 8669.38,
            "open": 8873.57,
            "volumefrom": 74704.5,
            "volumeto": 661168891
          }
        ],
        "TimeTo": 1524700800,
        "TimeFrom": 1523836800,
        "FirstValueInArray": true,
        "ConversionType": {
          "type": "direct",
          "conversionSymbol": ""
        }
      }
      """

      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, json) end)

      expected = [
        %{closing_price: Decimal.from_float(8804.32), date: ~D[2018-04-26], opening_price: Decimal.from_float(8873.57)}
      ]

      assert {:ok, expected} == CryptoCompare.fetch_history(3)
    end
  end
end
