defmodule BlockScoutWeb.FaucetController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Faucet}

  @internal_server_err_msg "Internal server error. Please try again later."
  @send_coins_failed_msg "Sending coins failed. Please try again later."
  @wrong_recipinet_msg "Wrong recipient address"

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
    case Chain.string_to_address_hash(receiver) do
      {:ok, address_hash} ->
        last_requested = Faucet.get_last_faucet_request_for_address(receiver)

        today = DateTime.utc_now()
        yesterday = Timex.shift(today, days: -1)

        if !last_requested || last_requested < yesterday do
          send_coins(receiver, address_hash, conn)
        else
          dur_to_next_available_request = calc_dur_to_next_available_request(last_requested, yesterday)

          json(conn, %{
            success: false,
            message:
              "You requested #{System.get_env("FAUCET_VALUE")} #{System.get_env("FAUCET_COIN")} within the last 24 hours. Next claim is in #{
                dur_to_next_available_request
              }"
          })
        end

      _ ->
        json(conn, %{
          success: false,
          message: @wrong_recipinet_msg
        })
    end
  end

  def request(conn, _), do: not_found(conn)

  defp calc_dur_to_next_available_request(last_requested, yesterday) do
    dur_sec = DateTime.diff(last_requested, yesterday, :second)
    dur_min_full = trunc(dur_sec / 60)
    dur_hrs = trunc(dur_min_full / 60)
    dur_min = dur_min_full - dur_hrs * 60

    "#{dur_hrs}:#{dur_min}"
  end

  defp send_coins(receiver, address_hash, conn) do
    case Faucet.send_coins_from_faucet(receiver) do
      {:ok, transaction_hash} ->
        case Faucet.insert_faucet_request_record(address_hash) do
          {:ok, _} -> json(conn, %{success: true, transactionHash: transaction_hash, message: "Success"})
          {:error, _} -> json(conn, %{success: false, message: @internal_server_err_msg})
        end

      {:error} ->
        json(conn, %{success: false, message: @send_coins_failed_msg})

      _ ->
        json(conn, %{success: false, message: @send_coins_failed_msg})
    end
  end
end
