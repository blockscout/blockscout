defmodule BlockScoutWeb.API.V2.OptimismView do
  use BlockScoutWeb, :view

  import Ecto.Query, only: [from: 2]

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.{Chain, Repo}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Optimism.{FrameSequenceBlob, Withdrawal}

  @doc """
    Function to render GET requests to `/api/v2/optimism/txn-batches` endpoint.
  """
  @spec render(binary(), map()) :: map() | list() | non_neg_integer()
  def render("optimism_txn_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    items =
      batches
      |> Enum.map(fn batch ->
        Task.async(fn ->
          tx_count =
            Repo.replica().aggregate(
              from(
                t in Transaction,
                inner_join: b in Block,
                on: b.hash == t.block_hash and b.consensus == true,
                where: t.block_number == ^batch.l2_block_number
              ),
              :count,
              timeout: :infinity
            )

          %{
            "l2_block_number" => batch.l2_block_number,
            "tx_count" => tx_count,
            "l1_tx_hashes" => batch.frame_sequence.l1_transaction_hashes,
            "l1_timestamp" => batch.frame_sequence.l1_timestamp
          }
        end)
      end)
      |> Task.yield_many(:infinity)
      |> Enum.map(fn {_task, {:ok, item}} -> item end)

    %{
      items: items,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/batches` endpoint.
  """
  def render("optimism_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    items =
      batches
      |> Enum.map(fn batch ->
        from..to = batch.l2_block_range

        %{
          "internal_id" => batch.id,
          "l1_timestamp" => batch.l1_timestamp,
          "l2_block_start" => from,
          "l2_block_end" => to,
          "tx_count" => batch.tx_count,
          "l1_tx_hashes" => batch.l1_transaction_hashes
        }
      end)

    %{
      items: items,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/batches/da/celestia/:height/:commitment`
    and `/api/v2/optimism/batches/:internal_id` endpoints.
  """
  def render("optimism_batch.json", %{batch: batch}) do
    batch
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/output-roots` endpoint.
  """
  def render("optimism_output_roots.json", %{
        roots: roots,
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
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/games` endpoint.
  """
  def render("optimism_games.json", %{
        games: games,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(games, fn g ->
          status =
            case g.status do
              0 -> "In progress"
              1 -> "Challenger wins"
              2 -> "Defender wins"
            end

          [l2_block_number] = ExplorerHelper.decode_data(g.extra_data, [{:uint, 256}])

          %{
            "index" => g.index,
            "game_type" => g.game_type,
            "contract_address" => g.address,
            "l2_block_number" => l2_block_number,
            "created_at" => g.created_at,
            "status" => status,
            "resolved_at" => g.resolved_at
          }
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/deposits` endpoint.
  """
  def render("optimism_deposits.json", %{
        deposits: deposits,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(deposits, fn deposit ->
          %{
            "l1_block_number" => deposit.l1_block_number,
            "l2_tx_hash" => deposit.l2_transaction_hash,
            "l1_block_timestamp" => deposit.l1_block_timestamp,
            "l1_tx_hash" => deposit.l1_transaction_hash,
            "l1_tx_origin" => deposit.l1_transaction_origin,
            "l2_tx_gas_limit" => deposit.l2_transaction.gas
          }
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/main-page/optimism-deposits` endpoint.
  """
  def render("optimism_deposits.json", %{deposits: deposits}) do
    Enum.map(deposits, fn deposit ->
      %{
        "l1_block_number" => deposit.l1_block_number,
        "l1_block_timestamp" => deposit.l1_block_timestamp,
        "l1_tx_hash" => deposit.l1_transaction_hash,
        "l2_tx_hash" => deposit.l2_transaction_hash
      }
    end)
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/withdrawals` endpoint.
  """
  def render("optimism_withdrawals.json", %{
        withdrawals: withdrawals,
        next_page_params: next_page_params,
        conn: conn
      }) do
    respected_games = Withdrawal.respected_games()

    %{
      items:
        Enum.map(withdrawals, fn w ->
          msg_nonce =
            Bitwise.band(
              Decimal.to_integer(w.msg_nonce),
              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )

          msg_nonce_version = Bitwise.bsr(Decimal.to_integer(w.msg_nonce), 240)

          {from_address, from_address_hash} =
            with false <- is_nil(w.from),
                 {:ok, address} <-
                   Chain.hash_to_address(
                     w.from,
                     [
                       necessity_by_association: %{
                         :names => :optional,
                         :smart_contract => :optional,
                         :proxy_implementations => :optional
                       },
                       api?: true
                     ],
                     false
                   ) do
              {address, address.hash}
            else
              _ -> {nil, nil}
            end

          {status, challenge_period_end} = Withdrawal.status(w, respected_games)

          %{
            "msg_nonce_raw" => Decimal.to_string(w.msg_nonce, :normal),
            "msg_nonce" => msg_nonce,
            "msg_nonce_version" => msg_nonce_version,
            "from" => Helper.address_with_info(conn, from_address, from_address_hash, w.from),
            "l2_tx_hash" => w.l2_transaction_hash,
            "l2_timestamp" => w.l2_timestamp,
            "status" => status,
            "l1_tx_hash" => w.l1_transaction_hash,
            "challenge_period_end" => challenge_period_end
          }
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/:entity/count` endpoints.
  """
  def render("optimism_items_count.json", %{count: count}) do
    count
  end

  @doc """
    Extends the json output for a block using Optimism frame sequence (bound
    with the provided L2 block) - adds info about L1 batch to the output.

    ## Parameters
    - `out_json`: A map defining output json which will be extended.
    - `block`: block structure containing frame sequence info related to the block.

    ## Returns
    An extended map containing `optimism` item with the Optimism batch info
    (L1 transaction hashes, timestamp, related blobs).
  """
  @spec extend_block_json_response(map(), %{
          :__struct__ => Explorer.Chain.Block,
          :op_frame_sequence => any(),
          optional(any()) => any()
        }) :: map()
  def extend_block_json_response(out_json, %Block{} = block) do
    frame_sequence = Map.get(block, :op_frame_sequence)

    if is_nil(frame_sequence) do
      out_json
    else
      {batch_data_container, blobs} = FrameSequenceBlob.list(frame_sequence.id, api?: true)

      batch_info =
        %{
          "internal_id" => frame_sequence.id,
          "l1_timestamp" => frame_sequence.l1_timestamp,
          "l1_tx_hashes" => frame_sequence.l1_transaction_hashes,
          "batch_data_container" => batch_data_container
        }
        |> extend_batch_info_by_blobs(blobs, "blobs")

      Map.put(out_json, "optimism", batch_info)
    end
  end

  defp extend_batch_info_by_blobs(batch_info, blobs, field_name) do
    if Enum.empty?(blobs) do
      batch_info
    else
      Map.put(batch_info, field_name, blobs)
    end
  end

  @doc """
    Extends the json output for a transaction adding Optimism-related info to the output.

    ## Parameters
    - `out_json`: A map defining output json which will be extended.
    - `transaction`: transaction structure containing extra Optimism-related info.

    ## Returns
    An extended map containing `l1_*` and `op_withdrawals` items related to Optimism.
  """
  @spec extend_transaction_json_response(map(), %{
          :__struct__ => Explorer.Chain.Transaction,
          optional(any()) => any()
        }) :: map()
  def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
    out_json
    |> add_optional_transaction_field(transaction, :l1_fee)
    |> add_optional_transaction_field(transaction, :l1_fee_scalar)
    |> add_optional_transaction_field(transaction, :l1_gas_price)
    |> add_optional_transaction_field(transaction, :l1_gas_used)
    |> add_optimism_fields(transaction.hash)
  end

  defp add_optional_transaction_field(out_json, transaction, field) do
    case Map.get(transaction, field) do
      nil -> out_json
      value -> Map.put(out_json, Atom.to_string(field), value)
    end
  end

  defp add_optimism_fields(out_json, transaction_hash) do
    withdrawals =
      transaction_hash
      |> Withdrawal.transaction_statuses()
      |> Enum.map(fn {nonce, status, l1_transaction_hash} ->
        %{
          "nonce" => nonce,
          "status" => status,
          "l1_transaction_hash" => l1_transaction_hash
        }
      end)

    Map.put(out_json, "op_withdrawals", withdrawals)
  end
end
