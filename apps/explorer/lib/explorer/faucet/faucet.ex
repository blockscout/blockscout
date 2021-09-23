defmodule Explorer.Faucet do
  @moduledoc """
  Context for data related to the faucet.
  """
  alias ETH
  alias Explorer.Faucet.FaucetRequest
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Transaction

  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [json_rpc: 2, request: 1]

  def get_last_faucet_request_for_address(receiver) do
    last_requested_query =
      from(faucet in FaucetRequest,
        where: faucet.receiver_hash == ^receiver,
        select: max(faucet.inserted_at)
      )

    last_requested_query
    |> Repo.one()
  end

  def get_last_faucet_request_for_phone(phone_hash) do
    last_requested_query =
      from(faucet in FaucetRequest,
        where: faucet.phone_hash == ^phone_hash,
        where: faucet.coins_sent == true,
        select: max(faucet.inserted_at)
      )

    last_requested_query
    |> Repo.one()
  end

  def get_faucet_request_data(address_hash, phone_hash, session_key_hash) do
    code_validation_attempts_query =
      from(faucet in FaucetRequest,
        where: faucet.receiver_hash == ^address_hash,
        where: faucet.phone_hash == ^phone_hash,
        where: faucet.session_key_hash == ^session_key_hash,
        select: %{
          verification_code_validation_attempts: faucet.verification_code_validation_attempts,
          verification_code: faucet.verification_code_hash
        }
      )

    code_validation_attempts_query
    |> Repo.one()
  end

  def count_sent_sms_today(phone_hash) do
    count_sent_sms_query =
      from(faucet in FaucetRequest,
        where: faucet.phone_hash == ^phone_hash,
        where: fragment("DATE(?) = CURRENT_DATE", faucet.inserted_at),
        select: count(faucet)
      )

    count_sent_sms_query
    |> Repo.one()
  end

  def insert_faucet_request_record(address_hash, phone_hash, session_key_hash, verification_code_hash) do
    with {:ok, _} <- Chain.find_or_insert_address_from_hash(address_hash, [], false) do
      changeset =
        FaucetRequest.changeset(%FaucetRequest{}, %{
          receiver_hash: address_hash,
          phone_hash: phone_hash,
          session_key_hash: session_key_hash,
          verification_code_hash: verification_code_hash,
          verification_code_validation_attempts: 0
        })

      Repo.insert(changeset)
    end
  end

  def update_faucet_request_code_validation_attempts(address_hash, phone_hash, session_key_hash) do
    faucet_request =
      Repo.get_by(FaucetRequest,
        receiver_hash: address_hash,
        phone_hash: phone_hash,
        session_key_hash: session_key_hash
      )

    if faucet_request do
      verification_code_validation_attempts =
        if faucet_request.verification_code_validation_attempts do
          faucet_request.verification_code_validation_attempts + 1
        else
          1
        end

      changeset =
        FaucetRequest.changeset(faucet_request, %{
          verification_code_validation_attempts: verification_code_validation_attempts
        })

      Repo.update(changeset)
    else
      :error
    end
  end

  def process_faucet_request(address_hash, phone_hash, session_key_hash, coins_sent) do
    faucet_request =
      Repo.get_by(FaucetRequest,
        receiver_hash: address_hash,
        phone_hash: phone_hash,
        session_key_hash: session_key_hash
      )

    if faucet_request do
      changeset =
        FaucetRequest.changeset(faucet_request, %{
          coins_sent: coins_sent
        })

      Repo.update(changeset)
    else
      {:error, "faucet request history item is missing"}
    end
  end

  def address_contains_outgoing_transactions_after_time(receiver, last_requested) do
    Repo.exists?(
      from(
        t in Transaction,
        where: t.from_address_hash == ^receiver,
        where: t.to_address_hash != ^receiver,
        where: t.inserted_at >= ^last_requested
      )
    )
  end

  def send_coins_from_faucet(address_hash) do
    address_hash_str = address_hash |> to_string()

    case eth_sign_transaction_request(1, address_hash_str) do
      {:ok, signed_tx} ->
        eth_send_raw_transaction_request(1, signed_tx)

      _ ->
        {:error}
    end
  end

  defp eth_get_transaction_count_request(id) do
    address_hash_str = Application.get_env(:block_scout_web, :faucet)[:address]
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    req =
      request(%{
        id: id,
        method: "eth_getTransactionCount",
        params: [address_hash_str, "pending"]
      })

    req
    |> json_rpc(json_rpc_named_arguments)
  end

  defp eth_sign_transaction_request(id, address_hash_str) do
    res = eth_get_transaction_count_request(id)

    with {:ok, nonce_hex} <- res do
      value_to_send_int = faucet_value_to_send_int()

      value_to_send =
        value_to_send_int
        |> Integer.to_string(16)

      value_to_send_hex = "0x" <> value_to_send

      gas_price_str = Application.get_env(:block_scout_web, :faucet)[:gas_price]

      gas_price_dec =
        1_000_000_000
        |> Decimal.new()
        |> Decimal.mult(Decimal.new(gas_price_str))

      gas_price_int =
        gas_price_dec
        |> Decimal.to_integer()

      gas_price =
        gas_price_int
        |> Integer.to_string(16)

      gas_price_hex = "0x" <> gas_price

      gas_limit_str = Application.get_env(:block_scout_web, :faucet)[:gas_limit]

      {gas_limit, _} =
        gas_limit_str
        |> Integer.parse()

      _raw_tx = %{
        from: Application.get_env(:block_scout_web, :faucet)[:address],
        nonce: nonce_hex,
        gas_price: gas_price_hex,
        gas_limit: gas_limit,
        to: address_hash_str,
        value: value_to_send_hex,
        data: "0x"
      }

      _faucet_address_pk = Application.get_env(:block_scout_web, :faucet)[:address_pk]

      # signed_tx =
      #   raw_tx
      #   |> ETH.build()
      #   |> ETH.sign_transaction(faucet_address_pk)
      #   |> Base.encode16(case: :lower)

      # {:ok, signed_tx}
      {:error}
    end
  end

  def faucet_value_to_send_int do
    value_to_send_str = Application.get_env(:block_scout_web, :faucet)[:value]

    value_to_send_dec =
      1_000_000_000_000_000_000
      |> Decimal.new()
      |> Decimal.mult(Decimal.new(value_to_send_str))

    value_to_send_dec
    |> Decimal.to_integer()
  end

  defp eth_send_raw_transaction_request(id, data) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    data =
      if String.starts_with?(data, "0x") do
        data
      else
        "0x" <> data
      end

    req =
      request(%{
        id: id,
        method: "eth_sendRawTransaction",
        params: [data]
      })

    req
    |> json_rpc(json_rpc_named_arguments)
  end
end
