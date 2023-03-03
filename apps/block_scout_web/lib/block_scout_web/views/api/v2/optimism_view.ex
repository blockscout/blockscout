defmodule BlockScoutWeb.API.V2.OptimismView do
  use BlockScoutWeb, :view

  import Ecto.Query, only: [from: 2]

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{OptimismOutputRoot, OptimismWithdrawalEvent, Transaction}

  def render("optimism_txn_batches.json", %{
        batches: batches,
        total: total,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(batches, fn batch ->
          tx_count =
            Repo.aggregate(from(t in Transaction, where: t.block_number == ^batch.l2_block_number), :count,
              timeout: :infinity
            )

          %{
            "l2_block_number" => batch.l2_block_number,
            "tx_count" => tx_count,
            "epoch_number" => batch.epoch_number,
            "l1_tx_hashes" => batch.l1_transaction_hashes,
            "l1_timestamp" => batch.l1_timestamp
          }
        end),
      total: total,
      next_page_params: next_page_params
    }
  end

  def render("output_roots.json", %{
        roots: roots,
        total: total,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(roots, fn r ->
          %{
            "l2_output_index" => r.l2_output_index,
            "l2_block_number" => r.l2_block_number,
            "l1_tx_hash" => r.l1_transaction_hash,
            "l1_timestamp" => r.l1_timestamp,
            "l1_block_number" => r.l1_block_number,
            "output_root" => r.output_root
          }
        end),
      total: total,
      next_page_params: next_page_params
    }
  end

  def render("optimism_withdrawals.json", %{
        withdrawals: withdrawals,
        total: total,
        next_page_params: next_page_params,
        conn: conn
      }) do
    %{
      items:
        Enum.map(withdrawals, fn w ->
          msg_nonce =
            Bitwise.band(
              Decimal.to_integer(w.msg_nonce),
              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )

          msg_nonce_version = Bitwise.bsr(Decimal.to_integer(w.msg_nonce), 240)

          from_address =
            with false <- is_nil(w.from),
                 {:ok, address} <-
                   Chain.hash_to_address(
                     w.from,
                     [necessity_by_association: %{:names => :optional, :smart_contract => :optional}],
                     false
                   ) do
              address
            else
              _ -> nil
            end

          {status, challenge_period_end} = withdrawal_status(w)

          %{
            "msg_nonce_raw" => Decimal.to_string(w.msg_nonce, :normal),
            "msg_nonce" => msg_nonce,
            "msg_nonce_version" => msg_nonce_version,
            "from" => Helper.address_with_info(conn, from_address, w.from),
            "l2_tx_hash" => w.l2_transaction_hash,
            "l2_timestamp" => w.l2_timestamp,
            "status" => status,
            "l1_tx_hash" => w.l1_transaction_hash,
            "challenge_period_end" => challenge_period_end
          }
        end),
      total: total,
      next_page_params: next_page_params
    }
  end

  defp withdrawal_status(w) do
    if is_nil(w.l1_transaction_hash) do
      l1_timestamp =
        Repo.one(
          from(
            we in OptimismWithdrawalEvent,
            select: we.l1_timestamp,
            where: we.withdrawal_hash == ^w.withdrawal_hash and we.l1_event_type == :WithdrawalProven
          )
        )

      if is_nil(l1_timestamp) do
        last_root_timestamp =
          Repo.one(
            from(root in OptimismOutputRoot,
              select: root.l1_timestamp,
              order_by: [desc: root.l2_output_index],
              limit: 1
            )
          ) || 0

        if w.l2_timestamp > last_root_timestamp do
          {"Waiting for state root", nil}
        else
          {"Ready to prove", nil}
        end
      else
        if DateTime.compare(l1_timestamp, DateTime.add(DateTime.utc_now(), -604_800, :second)) == :lt do
          {"Ready for relay", nil}
        else
          {"In challenge period", DateTime.add(l1_timestamp, 604_800, :second)}
        end
      end
    else
      {"Relayed", nil}
    end
  end
end
