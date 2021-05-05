defmodule BlockScoutWeb.FaucetController do
  use BlockScoutWeb, :controller

  require Logger

  alias Explorer.{Chain, Faucet}
  alias Explorer.Faucet.PhoneNumberLookup
  alias ExTwilio.Message

  @internal_server_err_msg "Internal server error. Please try again later."
  @send_coins_failed_msg "Sending coins failed. Please try again later."
  @wrong_recipinet_msg "Wrong recipient address"
  @wrond_captcha_response "Wrong captcha response"

  @max_code_validation_attempts 3
  @max_sms_sent_per_number_per_day 3

  def index(conn, params) do
    []
    |> handle_render(conn, params)
  end

  defp handle_render(_full_options, conn, _params) do
    if Application.get_env(:block_scout_web, :faucet)[:enabled] do
      render(conn, "index.html")
    else
      not_found(conn)
    end
  end

  def request(conn, %{
        "receiver" => receiver,
        "phoneNumber" => phone_number,
        "sessionKeyHash" => session_key_hash,
        "verificationCodeHash" => verification_code_hash,
        "captchaResponse" => captcha_response
      }) do
    if Application.get_env(:block_scout_web, :faucet)[:enabled] do
      with {:ok, address_hash, captcha_response: %{status_code: status_code, body: body}} <-
             validate_address_and_captcha(conn, receiver, captcha_response),
           {:ok, sanitized_phone_number} <- sanitize_phone_number(phone_number),
           {:ok, phone_hash} <- generate_phone_hash(conn, sanitized_phone_number),
           :ok <- parse_request_interval_response(conn, status_code, body, address_hash, phone_hash),
           :ok <- parse_verify_code_response(conn, verification_code_hash, address_hash, phone_hash, session_key_hash) do
        try_num = 0
        send_coins(address_hash, phone_hash, session_key_hash, conn, try_num)
      else
        res -> res
      end
    else
      json(conn, %{success: false, message: @internal_server_err_msg})
    end
  end

  def request(conn, %{
        "receiver" => receiver,
        "phoneNumber" => phone_number,
        "sessionKeyHash" => session_key_hash,
        "captchaResponse" => captcha_response
      }) do
    if Application.get_env(:block_scout_web, :faucet)[:enabled] do
      with {:ok, address_hash, captcha_response: %{status_code: status_code, body: body}} <-
             validate_address_and_captcha(conn, receiver, captcha_response),
           {:ok, sanitized_phone_number} <- sanitize_phone_number(phone_number),
           {:ok, phone_hash} <- generate_phone_hash(conn, sanitized_phone_number),
           :ok <- parse_check_number_of_sms_per_phone_number(conn, phone_hash),
           :ok <- parse_request_interval_response(conn, status_code, body, address_hash, phone_hash),
           :ok <- parse_enough_coins(conn),
           {:ok, _} <- phone_number_lookup(conn, sanitized_phone_number),
           {:ok, verification_code_hash} <-
             parse_send_sms_response(conn, sanitized_phone_number) do
        case Faucet.insert_faucet_request_record(
               address_hash,
               phone_hash,
               session_key_hash,
               verification_code_hash
             ) do
          {:ok, _} ->
            json(conn, %{success: true, message: "Success"})

          {:error, err} ->
            Logger.error(fn -> ["failed to insert faucet request history item: ", inspect(err)] end)
            json(conn, %{success: false, message: @internal_server_err_msg})
        end
      else
        res -> res
      end
    else
      json(conn, %{success: false, message: @internal_server_err_msg})
    end
  end

  def request(conn, _), do: not_found(conn)

  defp sanitize_phone_number(nil), do: nil

  defp sanitize_phone_number(phone_number) do
    sanitized_phone_number = phone_number |> String.split(~r"[^\d]", trim: true) |> Enum.join("")
    {:ok, sanitized_phone_number}
  end

  defp generate_phone_hash(conn, phone_number) when is_nil(phone_number) do
    json(conn, %{
      success: false,
      message: "Phone number is empty."
    })
  end

  defp generate_phone_hash(_conn, sanitized_phone_number) do
    salted_phone_number = sanitized_phone_number <> System.get_env("FAUCET_PHONE_NUMBER_SALT")
    ExKeccak.hash_256(salted_phone_number)
  end

  defp phone_number_lookup(conn, sanitized_phone_number) do
    case PhoneNumberLookup.check(sanitized_phone_number) do
      {:error, :virtual} ->
        json(conn, %{
          success: false,
          message: "VoIP phone numbers are prohibited."
        })

      {:error, :prohibited_operator} ->
        json(conn, %{
          success: false,
          message: "This carrier is prohibited."
        })

      {:error, :unknown} ->
        json(conn, %{
          success: false,
          message: "A wrong phone number provided."
        })

      res ->
        res
    end
  end

  defp parse_request_interval_response(conn, status_code, body, address_hash, phone_hash) do
    case check_request_interval(status_code, body, address_hash, phone_hash) do
      :already_requested ->
        json(conn, %{
          success: false,
          message: "This account already requested coins before but didn't spend them"
        })

      {:already_requested, dur_to_next_available_request} ->
        json(conn, %{
          success: false,
          message:
            "You requested #{System.get_env("FAUCET_VALUE")} #{System.get_env("FAUCET_COIN")} within the last 24 hours. Next claim is in #{
              dur_to_next_available_request
            }"
        })

      :wrong_captcha_response ->
        json(conn, %{
          success: false,
          message: @wrond_captcha_response
        })

      res ->
        res
    end
  end

  defp parse_enough_coins(conn) do
    faucet_address_hash_str = Application.get_env(:block_scout_web, :faucet)[:address]
    faucet_balance = ETH.get_balance!(faucet_address_hash_str, :wei)

    faucet_value_to_send = Faucet.faucet_value_to_send_int()

    if faucet_balance > faucet_value_to_send do
      :ok
    else
      json(conn, %{
        success: false,
        message: "Not enough coins on the faucet balance to send."
      })
    end
  end

  defp validate_address_and_captcha(conn, receiver, captcha_response) do
    with {:validate_address, {:ok, address_hash}} <- {:validate_address, Chain.string_to_address_hash(receiver)},
         {:validate_captcha, {:ok, %HTTPoison.Response{status_code: status_code, body: body}}} <-
           {:validate_captcha, validate_captcha_response(captcha_response)} do
      {:ok, address_hash, captcha_response: %{status_code: status_code, body: body}}
    else
      {:validate_address, _} ->
        json(conn, %{
          success: false,
          message: @wrong_recipinet_msg
        })

      {:validate_captcha, _} ->
        json(conn, %{
          success: false,
          message: @wrond_captcha_response
        })
    end
  end

  defp check_request_interval(status_code, body, address_hash, phone_hash) do
    last_requested = Faucet.get_last_faucet_request_for_phone(phone_hash)

    body_json = Jason.decode!(body)

    if status_code == 200 && Map.get(body_json, "success") do
      today = DateTime.utc_now()
      yesterday = Timex.shift(today, days: -1)

      if !last_requested || DateTime.diff(last_requested, yesterday, :second) <= 0 do
        if last_requested do
          if Faucet.address_contains_outgoing_transactions_after_time(address_hash, last_requested) do
            :ok
          else
            :already_requested
          end
        else
          :ok
        end
      else
        dur_to_next_available_request = calc_dur_to_next_available_request(last_requested, yesterday)

        {:already_requested, dur_to_next_available_request}
      end
    else
      :wrong_captcha_response
    end
  end

  defp check_number_of_sms_per_phone_number(phone_hash) do
    sent_sms = Faucet.count_sent_sms_today(phone_hash)

    if sent_sms >= @max_sms_sent_per_number_per_day do
      :sms_limit_per_day_reached
    else
      :ok
    end
  end

  defp parse_check_number_of_sms_per_phone_number(conn, phone_hash) do
    case check_number_of_sms_per_phone_number(phone_hash) do
      :sms_limit_per_day_reached ->
        json(conn, %{
          success: false,
          message: "You reached the maximum SMS delivery per day. Please try again tomorrow."
        })

      res ->
        res
    end
  end

  defp calc_dur_to_next_available_request(last_requested, yesterday) do
    dur_sec = DateTime.diff(last_requested, yesterday, :second)
    dur_min_full = trunc(dur_sec / 60)
    dur_hrs = trunc(dur_min_full / 60)
    dur_min = dur_min_full - dur_hrs * 60

    "#{dur_hrs}:#{dur_min}"
  end

  defp verify_code(verification_code_hash, address_hash, phone_hash, session_key_hash) do
    %{verification_code_validation_attempts: number_of_attempts, verification_code: saved_verification_code} =
      Faucet.get_faucet_request_data(address_hash, phone_hash, session_key_hash)

    number_of_left_attempts_raw = @max_code_validation_attempts - number_of_attempts

    number_of_left_attempts =
      max(
        number_of_left_attempts_raw,
        0
      )

    if number_of_left_attempts == 0 do
      {:error, :max_attempts_achieved}
    else
      saved_verification_code_hash = "0x" <> Base.encode16(saved_verification_code.bytes, case: :lower)

      code_verification =
        if saved_verification_code_hash !== verification_code_hash do
          :invalid_code
        else
          :valid_code
        end

      Faucet.update_faucet_request_code_validation_attempts(address_hash, phone_hash, session_key_hash)
      number_of_left_attempts = max(number_of_left_attempts - 1, 0)

      cond do
        code_verification == :invalid_code && number_of_left_attempts > 0 ->
          {:error, :invalid_code, number_of_left_attempts}

        code_verification == :invalid_code && number_of_left_attempts == 0 ->
          {:error, :invalid_code, :max_attempts_achieved}

        code_verification == :valid_code ->
          :ok
      end
    end
  end

  defp parse_verify_code_response(conn, verification_code_hash, address_hash, phone_hash, session_key_hash) do
    case verify_code(verification_code_hash, address_hash, phone_hash, session_key_hash) do
      :ok ->
        :ok

      {:error, :max_attempts_achieved} ->
        json(conn, %{
          success: false,
          message: "You reached the maximum of code validation attempts. Try from the beginning."
        })

      {:error, :invalid_code, :max_attempts_achieved} ->
        json(conn, %{
          success: false,
          message:
            "Verification code is invalid. You reached the maximum of code validation attempts. The next try will be available in ..."
        })

      {:error, :invalid_code, number_of_left_attempts} ->
        json(conn, %{
          success: false,
          message: "Verification code is invalid. The number of left attempts is #{number_of_left_attempts}"
        })
    end
  end

  defp send_sms(phone_number) do
    verification_code = :rand.uniform(999_999)
    body = "Blockscout faucet verification code: " <> to_string(verification_code)

    case Message.create(to: "+" <> to_string(phone_number), from: System.get_env("TWILIO_FROM"), body: body) do
      {:ok, _} -> ExKeccak.hash_256(to_string(verification_code))
      res -> res
    end
  end

  defp parse_send_sms_response(conn, phone_number) do
    case send_sms(phone_number) do
      :error ->
        json(conn, %{
          success: false,
          message: "Failed to send SMS. Please try again later"
        })

      {:error, error} ->
        Logger.error(inspect(error))

        json(conn, %{
          success: false,
          message: "Failed to send SMS. Please try again later"
        })

      {:error, error, _} ->
        Logger.error(inspect(error))

        json(conn, %{
          success: false,
          message: "Failed to send SMS. Please try again later"
        })

      res ->
        res
    end
  end

  defp send_coins(address_hash, phone_hash, session_key_hash, conn, try_num) do
    if try_num < 5 do
      case Faucet.process_faucet_request(address_hash, phone_hash, session_key_hash, true) do
        {:ok, _} ->
          case Faucet.send_coins_from_faucet(address_hash) do
            {:ok, transaction_hash} ->
              json(conn, %{success: true, transactionHash: transaction_hash, message: "Success"})

            err ->
              Logger.error(fn ->
                [
                  "failed to send coins from faucet to address: ",
                  inspect(address_hash |> to_string()),
                  ": ",
                  inspect(err)
                ]
              end)

              try_num = try_num + 1
              Process.sleep(500)

              with {:ok, _} <- Faucet.process_faucet_request(address_hash, phone_hash, session_key_hash, nil) do
                send_coins(address_hash, phone_hash, session_key_hash, conn, try_num)
              end
          end

        {:error, err} ->
          Logger.error(fn -> ["failed to update faucet request history item: ", inspect(err)] end)
          json(conn, %{success: false, message: @internal_server_err_msg})
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
