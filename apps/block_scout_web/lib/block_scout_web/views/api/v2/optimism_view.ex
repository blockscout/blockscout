defmodule BlockScoutWeb.API.V2.OptimismView do
  use BlockScoutWeb, :view

  import Ecto.Query, only: [from: 2]

  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Optimism.{DisputeGame, FrameSequence, FrameSequenceBlob, InteropMessage, Withdrawal}

  @doc """
    Function to render GET requests to `/api/v2/optimism/txn-batches` endpoint.
  """
  @spec render(binary(), map()) :: map() | list() | non_neg_integer()
  def render("optimism_transaction_batches.json", %{
        batches: batches,
        next_page_params: next_page_params
      }) do
    items =
      batches
      |> Enum.map(fn batch ->
        Task.async(fn ->
          transaction_count =
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
            "transactions_count" => transaction_count,
            # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
            "transaction_count" => transaction_count,
            "l1_transaction_hashes" => batch.frame_sequence.l1_transaction_hashes,
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
        from..to//_ = batch.l2_block_range

        render_base_info_for_batch(batch.id, from, to, batch.transactions_count, batch)
      end)

    %{
      items: items,
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/batches/da/celestia/:height/:commitment`
    and `/api/v2/optimism/batches/:number` endpoints.
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
            "l1_transaction_hash" => r.l1_transaction_hash,
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

          l2_block_number = DisputeGame.l2_block_number_from_extra_data(g.extra_data)

          %{
            "index" => g.index,
            "game_type" => g.game_type,
            # todo: It should be removed in favour `contract_address_hash` property with the next release after 8.0.0
            "contract_address" => g.address_hash,
            "contract_address_hash" => g.address_hash,
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
            "l2_transaction_hash" => deposit.l2_transaction_hash,
            "l1_block_timestamp" => deposit.l1_block_timestamp,
            "l1_transaction_hash" => deposit.l1_transaction_hash,
            "l1_transaction_origin" => deposit.l1_transaction_origin,
            "l2_transaction_gas_limit" => deposit.l2_transaction.gas
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
        "l1_transaction_hash" => deposit.l1_transaction_hash,
        "l2_transaction_hash" => deposit.l2_transaction_hash
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
                     necessity_by_association: %{
                       :names => :optional,
                       :smart_contract => :optional,
                       proxy_implementations_association() => :optional
                     },
                     api?: true
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
            "l2_transaction_hash" => w.l2_transaction_hash,
            "l2_timestamp" => w.l2_timestamp,
            "status" => status,
            "l1_transaction_hash" => w.l1_transaction_hash,
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
    Function to render GET requests to `/api/v2/optimism/interop/messages` endpoint.
  """
  def render("optimism_interop_messages.json", %{
        messages: messages,
        next_page_params: next_page_params
      }) do
    %{
      items:
        Enum.map(messages, fn message ->
          msg =
            %{
              "unique_id" => InteropMessage.message_unique_id(message),
              "nonce" => message.nonce,
              "timestamp" => message.timestamp,
              "status" => message.status,
              "init_transaction_hash" => message.init_transaction_hash,
              "relay_transaction_hash" => message.relay_transaction_hash,
              "sender_address_hash" => message.sender_address_hash,
              # todo: keep next line for compatibility with frontend and remove when new frontend is bound to `sender_address_hash` property
              "sender" => message.sender_address_hash,
              "target_address_hash" => message.target_address_hash,
              # todo: keep next line for compatibility with frontend and remove when new frontend is bound to `target_address_hash` property
              "target" => message.target_address_hash,
              "payload" => message.payload
            }

          # add chain info depending on whether this is incoming or outgoing message
          msg
          |> maybe_add_chain(:init_chain, message)
          |> maybe_add_chain(:relay_chain, message)
        end),
      next_page_params: next_page_params
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/interop/messages/:unique_id` endpoint.
  """
  def render("optimism_interop_message.json", %{message: message}) do
    %{
      "init_chain" => message.init_chain,
      "init_transaction_hash" => message.init_transaction_hash,
      "timestamp" => message.timestamp,
      "sender_address_hash" => message.sender_address_hash,
      "relay_chain" => message.relay_chain,
      "relay_transaction_hash" => message.relay_transaction_hash,
      "relay_transaction_failed" => message.failed,
      "target_address_hash" => message.target_address_hash,
      "transfer_token" => message.transfer_token,
      "transfer_amount" => message.transfer_amount,
      "transfer_from_address_hash" => message.transfer_from_address_hash,
      "transfer_to_address_hash" => message.transfer_to_address_hash,
      "nonce" => message.nonce,
      "direction" => message.direction,
      "status" => message.status,
      "payload" => message.payload
    }
  end

  @doc """
    Function to render GET requests to `/api/v2/optimism/interop/public-key` endpoint.
  """
  def render("optimism_interop_public_key.json", %{public_key: public_key}) do
    %{"public_key" => public_key}
  end

  @doc """
    Function to render `relay` response for the POST request to `/api/v2/import/optimism/interop/` endpoint.
  """
  def render("optimism_interop_response.json", %{relay_transaction_hash: relay_transaction_hash, failed: failed}) do
    %{
      "relay_transaction_hash" => relay_transaction_hash,
      "failed" => failed
    }
  end

  @doc """
    Function to render `init` response for the POST request to `/api/v2/import/optimism/interop/` endpoint.
  """
  def render("optimism_interop_response.json", %{
        sender_address_hash: sender_address_hash,
        target_address_hash: target_address_hash,
        init_transaction_hash: init_transaction_hash,
        timestamp: timestamp,
        payload: payload
      }) do
    %{
      "sender_address_hash" => sender_address_hash,
      "target_address_hash" => target_address_hash,
      "init_transaction_hash" => init_transaction_hash,
      "timestamp" => if(not is_nil(timestamp), do: DateTime.to_unix(timestamp)),
      "payload" => payload
    }
  end

  # Transforms an L1 batch into a map format for HTTP response.
  #
  # This function processes an Optimism L1 batch and converts it into a map that
  # includes basic batch information.
  #
  # ## Parameters
  # - `internal_id`: The internal ID of the batch.
  # - `l2_block_number_from`: Start L2 block number of the batch block range.
  # - `l2_block_number_to`: End L2 block number of the batch block range.
  # - `transaction_count`: The L2 transaction count included into the blocks of the range.
  # - `batch`: Either an `Explorer.Chain.Optimism.FrameSequence` entry or a map with
  #            the corresponding fields.
  #
  # ## Returns
  # - A map with detailed information about the batch formatted for use in JSON HTTP responses.
  @spec render_base_info_for_batch(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          FrameSequence.t()
          | %{:l1_timestamp => DateTime.t(), :l1_transaction_hashes => list(), optional(any()) => any()}
        ) :: %{
          :number => non_neg_integer(),
          :internal_id => non_neg_integer(),
          :l1_timestamp => DateTime.t(),
          :l2_start_block_number => non_neg_integer(),
          :l2_block_start => non_neg_integer(),
          :l2_end_block_number => non_neg_integer(),
          :l2_block_end => non_neg_integer(),
          :transactions_count => non_neg_integer(),
          :transaction_count => non_neg_integer(),
          :l1_transaction_hashes => list(),
          :batch_data_container => :in_blob4844 | :in_celestia | :in_calldata | nil
        }
  defp render_base_info_for_batch(internal_id, l2_block_number_from, l2_block_number_to, transaction_count, batch) do
    FrameSequence.prepare_base_info_for_batch(
      internal_id,
      l2_block_number_from,
      l2_block_number_to,
      transaction_count,
      batch.batch_data_container,
      batch
    )
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
          "number" => frame_sequence.id,
          # todo: It should be removed in favour `number` property with the next release after 8.0.0
          "internal_id" => frame_sequence.id,
          "l1_timestamp" => frame_sequence.l1_timestamp,
          "l1_transaction_hashes" => frame_sequence.l1_transaction_hashes,
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

    interop_messages =
      transaction_hash
      |> InteropMessage.messages_by_transaction()

    out_json = Map.put(out_json, "op_withdrawals", withdrawals)

    if interop_messages == [] do
      out_json
    else
      out_json
      |> Map.put("op_interop_messages", interop_messages)
      # TODO: remove the deprecated `op_interop` map after frontend switches to the new `op_interop_messages`
      |> Map.put("op_interop", Enum.at(interop_messages, 0))
    end
  end

  defp maybe_add_chain(msg, chain_key, message) do
    case Map.fetch(message, chain_key) do
      {:ok, chain} -> Map.put(msg, Atom.to_string(chain_key), chain)
      _ -> msg
    end
  end
end
