defmodule BlockScoutWeb.FaucetController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Faucet}

  def index(conn, params) do
    []
    |> handle_render(conn, params)
  end

  defp handle_render(_full_options, conn, _params) do
    render(conn, "index.html")
  end

  def request(conn, %{
        "receiver" => receiver
      }) do
    last_requested = Faucet.get_last_faucet_request_for_address(receiver)

    today = DateTime.utc_now()
    yesterday = Timex.shift(today, days: -1)

    {:ok, address_hash} = Chain.string_to_address_hash(receiver)

    if !last_requested || last_requested < yesterday do
      case Faucet.send_coins_from_faucet(receiver) do
        {:ok, transaction_hash} ->
          case Faucet.insert_faucet_request_record(address_hash) do
            {:ok, _} -> json(conn, %{success: true, transactionHash: transaction_hash, message: "Success"})
            {:error, _} -> json(conn, %{success: false, message: "Internal server error"})
          end

        {:error} ->
          json(conn, %{success: false, message: "Internal server error"})
      end
    else
      dur_sec = DateTime.diff(last_requested, yesterday, :second)
      dur_min_full = trunc(dur_sec / 60)
      dur_hrs = trunc(dur_min_full / 60)
      dur_min = dur_min_full - dur_hrs * 60

      json(conn, %{
        success: false,
        message:
          "You requested #{System.get_env("FAUCET_VALUE")} #{System.get_env("FAUCET_COIN")} within the last 24 hours. Next claim is in #{
            dur_hrs
          }:#{dur_min}"
      })
    end
  end

  def request(conn, _), do: not_found(conn)
end
