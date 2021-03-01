defmodule BlockScoutWeb.FaucetController do
  use BlockScoutWeb, :controller

  require Logger

  alias Explorer.{Chain, Faucet}

  @internal_server_err_msg "Internal server error. Please try again later."
  @send_coins_failed_msg "Sending coins failed. Please try again later."
  @wrong_recipinet_msg "Wrong recipient address"
  @wrond_captcha_response "Wrong captcha response"

  def index(conn, params) do
    []
    |> handle_render(conn, params)
  end

  defp handle_render(_full_options, conn, _params) do
    render(conn, "index.html")
  end

  def request(conn, %{
        "receiver" => receiver,
        "captchaResponse" => captcha_response
      }) do
    case Chain.string_to_address_hash(receiver) do
      {:ok, address_hash} ->
        res = validate_captcha_response(captcha_response)

        case res do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            check_request_interval_and_send(conn, status_code, body, address_hash)

          _ ->
            json(conn, %{
              success: false,
              message: @wrond_captcha_response
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

  defp check_request_interval_and_send(conn, status_code, body, address_hash) do
    last_requested = Faucet.get_last_faucet_request_for_address(address_hash)

    body_json = Jason.decode!(body)

    if status_code == 200 && Map.get(body_json, "success") do
      today = DateTime.utc_now()
      yesterday = Timex.shift(today, days: -1)

      if !last_requested || DateTime.diff(last_requested, yesterday, :second) <= 0 do
        try_num = 0

        if last_requested do
          if Faucet.address_contains_outgoing_transactions_after_time(address_hash, last_requested) do
            send_coins(address_hash, conn, try_num)
          else
            json(conn, %{
              success: false,
              message: "This account already requested coins before but didn't spend them"
            })
          end
        else
          send_coins(address_hash, conn, try_num)
        end
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
    else
      json(conn, %{
        success: false,
        message: @wrond_captcha_response
      })
    end
  end

  defp calc_dur_to_next_available_request(last_requested, yesterday) do
    dur_sec = DateTime.diff(last_requested, yesterday, :second)
    dur_min_full = trunc(dur_sec / 60)
    dur_hrs = trunc(dur_min_full / 60)
    dur_min = dur_min_full - dur_hrs * 60

    "#{dur_hrs}:#{dur_min}"
  end

  defp send_coins(address_hash, conn, try_num) do
    if try_num < 5 do
      case Faucet.send_coins_from_faucet(address_hash) do
        {:ok, transaction_hash} ->
          case Faucet.insert_faucet_request_record(address_hash) do
            {:ok, _} ->
              json(conn, %{success: true, transactionHash: transaction_hash, message: "Success"})

            {:error, err} ->
              Logger.error(fn -> ["failed to insert faucet request history item: ", inspect(err)] end)
              json(conn, %{success: false, message: @internal_server_err_msg})
          end

        err ->
          Logger.error(fn ->
            ["failed to send coins from faucet to address: ", inspect(address_hash |> to_string()), ": ", inspect(err)]
          end)

          try_num = try_num + 1
          Process.sleep(500)
          send_coins(address_hash, conn, try_num)
      end
    else
      json(conn, %{success: false, message: @send_coins_failed_msg})
    end
  end

  defp validate_captcha_response(captcha_response) do
    body =
      "secret=#{Application.get_env(:block_scout_web, :faucet)[:h_captcha_secret_key]}&response=#{captcha_response}"

    headers = [{"Content-type", "application/x-www-form-urlencoded"}]

    HTTPoison.post("https://hcaptcha.com/siteverify", body, headers, [])
  end
end
