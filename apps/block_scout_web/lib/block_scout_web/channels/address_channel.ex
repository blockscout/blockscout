defmodule BlockScoutWeb.AddressChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates.
  """
  use BlockScoutWeb, :channel
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias BlockScoutWeb.{
    AddressCoinBalanceView,
    AddressView,
    InternalTransactionView,
    TransactionView
  }

  alias Explorer.{Chain, Market, Repo}
  alias Explorer.Chain.{Hash, Transaction, Wei}
  alias Explorer.Chain.Hash.Address, as: AddressHash
  alias Phoenix.View

  intercept([
    "balance_update",
    "coin_balance",
    "count",
    "internal_transaction",
    "transaction",
    "verification_result",
    "token_transfer",
    "pending_transaction"
  ])

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def join("addresses_old:" <> address_hash_string, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(address_hash_string) do
      :ok ->
        {:ok, %{}, assign(socket, :address_hash, address_hash_string)}

      reason ->
        {:error, %{reason: reason}}
    end
  end

  def handle_in("get_balance", _, socket) do
    with {:ok, casted_address_hash} <- AddressHash.cast(socket.assigns.address_hash),
         {:ok, address = %{fetched_coin_balance: balance}} when not is_nil(balance) <-
           Chain.hash_to_address(casted_address_hash),
         exchange_rate <- Market.get_coin_exchange_rate(),
         {:ok, rendered} <- render_balance_card(address, exchange_rate, socket) do
      reply =
        {:ok,
         %{
           balance_card: rendered,
           balance: address.fetched_coin_balance.value,
           fetched_coin_balance_block_number: address.fetched_coin_balance_block_number
         }}

      {:reply, reply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_out(
        "balance_update",
        %{address: address, exchange_rate: exchange_rate},
        socket
      ) do
    case render_balance_card(address, exchange_rate, socket) do
      {:ok, rendered} ->
        push(socket, "balance", %{
          balance_card: rendered,
          balance: address.fetched_coin_balance.value,
          fetched_coin_balance_block_number: address.fetched_coin_balance_block_number
        })

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_out("verification_result", result, socket) do
    case result[:result] do
      {:ok, _contract} ->
        push(socket, "verification", %{verification_result: :ok})
        {:noreply, socket}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, socket}

      {:error, result} ->
        push(socket, "verification", %{verification_result: result})
        {:noreply, socket}
    end
  end

  def handle_out("count", %{count: count}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    push(socket, "count", %{count: BlockScoutWeb.Cldr.Number.to_string!(count, format: "#,###")})

    {:noreply, socket}
  end

  def handle_out("internal_transaction", %{address: address, internal_transaction: internal_transaction}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_internal_transaction =
      View.render_to_string(
        InternalTransactionView,
        "_tile.html",
        current_address: address,
        internal_transaction: internal_transaction
      )

    push(socket, "internal_transaction", %{
      to_address_hash: to_string(internal_transaction.to_address_hash),
      from_address_hash: to_string(internal_transaction.from_address_hash),
      internal_transaction_html: rendered_internal_transaction
    })

    {:noreply, socket}
  end

  def handle_out("transaction", data, socket), do: handle_transaction(data, socket, "transaction")

  def handle_out("token_transfer", data, socket), do: handle_token_transfer(data, socket, "token_transfer")

  def handle_out("coin_balance", %{block_number: block_number, coin_balance: coin_balance}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    if coin_balance.value && coin_balance.delta do
      rendered_coin_balance =
        View.render_to_string(
          AddressCoinBalanceView,
          "_coin_balances.html",
          conn: socket,
          coin_balance: coin_balance
        )

      push(socket, "coin_balance", %{
        coin_balance_html: rendered_coin_balance
      })

      push_current_coin_balance(socket, block_number, coin_balance)
    end

    {:noreply, socket}
  end

  def handle_out("pending_transaction", data, socket), do: handle_transaction(data, socket, "transaction")

  def push_current_coin_balance(socket, block_number, coin_balance) do
    {:ok, hash} = Chain.string_to_address_hash(socket.assigns.address_hash)

    rendered_current_coin_balance =
      View.render_to_string(
        AddressView,
        "_current_coin_balance.html",
        conn: socket,
        address: Chain.hash_to_address(hash),
        coin_balance: (coin_balance && coin_balance.value) || %Wei{value: Decimal.new(0)},
        exchange_rate: Market.get_coin_exchange_rate()
      )

    rendered_link =
      View.render_to_string(
        AddressView,
        "_block_link.html",
        conn: socket,
        block_number: block_number
      )

    push(socket, "current_coin_balance", %{
      current_coin_balance_html: rendered_current_coin_balance,
      current_coin_balance_block_number_html: rendered_link,
      current_coin_balance_block_number: coin_balance.block_number
    })
  end

  def handle_transaction(
        %{address: address, transaction: transaction},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocket} = socket,
        event
      ) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        TransactionView,
        "_tile.html",
        conn: socket,
        current_address: address,
        transaction: transaction,
        burn_address_hash: @burn_address_hash
      )

    push(socket, event, %{
      to_address_hash: to_string(transaction.to_address_hash),
      from_address_hash: to_string(transaction.from_address_hash),
      transaction_hash: Hash.to_string(transaction.hash),
      transaction_html: rendered
    })

    {:noreply, socket}
  end

  def handle_transaction(_, socket, _event) do
    {:noreply, socket}
  end

  def handle_token_transfer(
        %{address: address, token_transfer: token_transfer},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocket} = socket,
        event
      ) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    transaction =
      Transaction
      |> Repo.get_by(hash: token_transfer.transaction_hash)
      |> Repo.preload([
        :from_address,
        :to_address,
        :block,
        :created_contract_address,
        token_transfers: [:from_address, :to_address, :token]
      ])

    rendered =
      View.render_to_string(
        TransactionView,
        "_tile.html",
        current_address: address,
        transaction: transaction,
        burn_address_hash: @burn_address_hash,
        conn: socket
      )

    push(socket, event, %{
      to_address_hash: to_string(token_transfer.to_address_hash),
      from_address_hash: to_string(token_transfer.from_address_hash),
      token_transfer_hash: Hash.to_string(token_transfer.transaction_hash),
      token_transfer_html: rendered
    })

    {:noreply, socket}
  end

  def handle_token_transfer(_, socket, _event) do
    {:noreply, socket}
  end

  defp render_balance_card(address, exchange_rate, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    try do
      rendered =
        View.render_to_string(
          AddressView,
          "_balance_dropdown.html",
          conn: socket,
          address: address,
          coin_balance_status: :current,
          exchange_rate: exchange_rate
        )

      {:ok, rendered}
    rescue
      _ ->
        :error
    end
  end
end
