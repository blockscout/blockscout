defmodule Explorer.Chain.Arbitrum.Reader.API.Messages do
  @moduledoc """
    Provides API-specific functions for querying Arbitrum cross-chain message data from the database.

    This module contains functions specifically designed for Blockscout's API endpoints
    that handle Arbitrum cross-chain message functionality. All functions in this module
    enforce the use of replica databases for read operations by automatically passing
    the `api?: true` option to database queries.

    The module includes functions for retrieving:
    - L2->L1 messages by transaction hash or message ID
    - L1->L2 messages that have been relayed
    - Message counts and paginated message lists

    Note: If any function from this module needs to be used outside of API handlers,
    it should be moved to `Explorer.Chain.Arbitrum.Reader.Common` with configurable
    database selection, and a wrapper function should be created in this module
    (see `Explorer.Chain.Arbitrum.Reader.API.Settlement.highest_confirmed_block/0` as an example).
  """

  import Ecto.Query, only: [from: 2, limit: 2, where: 3]
  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Arbitrum.Message
  alias Explorer.{Chain, PagingOptions}

  @api_true [api?: true]

  @doc """
    Retrieves L2-to-L1 messages initiated by specified transaction.

    The messages are filtered by the originating transaction hash (with any status).
    In the common case a transaction can initiate several messages.

    ## Parameters
    - `transaction_hash`: The transaction hash which initiated the messages.

    ## Returns
    - Instances of `Explorer.Chain.Arbitrum.Message` initiated by the transaction
      with the given hash, or `[]` if no messages with the given status are found.
  """
  @spec l2_to_l1_messages_by_transaction_hash(Chain.Hash.Full.t()) :: [Message.t()]
  def l2_to_l1_messages_by_transaction_hash(transaction_hash) do
    query =
      from(msg in Message,
        where: msg.direction == :from_l2 and msg.originating_transaction_hash == ^transaction_hash,
        order_by: [desc: msg.message_id]
      )

    query
    |> select_repo(@api_true).all()
  end

  @doc """
    Retrieves L2-to-L1 message by message id.

    ## Parameters
    - `message_id`: message ID

    ## Returns
    - Instance of `Explorer.Chain.Arbitrum.Message` with the provided message id,
      or nil if message with the given id doesn't exist.
  """
  @spec l2_to_l1_message_by_id(non_neg_integer()) :: Message.t() | nil
  def l2_to_l1_message_by_id(message_id) do
    query =
      from(message in Message,
        where: message.direction == :from_l2 and message.message_id == ^message_id
      )

    select_repo(@api_true).one(query)
  end

  @doc """
    Retrieves the count of cross-chain messages either sent to or from the rollup.

    ## Parameters
    - `direction`: A string that specifies the message direction; can be "from-rollup" or "to-rollup".

    ## Returns
    - The total count of cross-chain messages.
  """
  @spec messages_count(binary()) :: non_neg_integer()
  def messages_count(direction) when direction == "from-rollup" do
    do_messages_count(:from_l2)
  end

  def messages_count(direction) when direction == "to-rollup" do
    do_messages_count(:to_l2)
  end

  # Counts the number of cross-chain messages based on the specified direction.
  @spec do_messages_count(:from_l2 | :to_l2) :: non_neg_integer()
  defp do_messages_count(direction) do
    Message
    |> where([msg], msg.direction == ^direction)
    |> select_repo(@api_true).aggregate(:count)
  end

  @doc """
    Retrieves cross-chain messages based on the specified direction.

    This function constructs and executes a query to retrieve messages either sent
    to or from the rollup layer, applying pagination options. These options dictate
    not only the number of items to retrieve but also how many items to skip from
    the top.

    ## Parameters
    - `direction`: A string that can be "from-rollup" or "to-rollup", translated internally to `:from_l2` or `:to_l2`.
    - `options`: A keyword list which may contain `paging_options` specifying pagination details

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.Message` entries.
  """
  @spec messages(binary(), paging_options: PagingOptions.t()) :: [Message.t()]
  def messages(direction, options) when direction == "from-rollup" do
    do_messages(:from_l2, options)
  end

  def messages(direction, options) when direction == "to-rollup" do
    do_messages(:to_l2, options)
  end

  # Executes the query to fetch cross-chain messages based on the specified direction.
  #
  # This function constructs and executes a query to retrieve messages either sent
  # to or from the rollup layer, applying pagination options. These options dictate
  # not only the number of items to retrieve but also how many items to skip from
  # the top.
  #
  # ## Parameters
  # - `direction`: Can be either `:from_l2` or `:to_l2`, indicating the direction of the messages.
  # - `options`: A keyword list which may contain `paging_options` specifying pagination details
  #
  # ## Returns
  # - A list of `Explorer.Chain.Arbitrum.Message` entries matching the specified direction.
  @spec do_messages(:from_l2 | :to_l2, paging_options: PagingOptions.t()) :: [Message.t()]
  defp do_messages(direction, options) do
    base_query =
      from(msg in Message,
        where: msg.direction == ^direction,
        order_by: [desc: msg.message_id]
      )

    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      base_query
      |> page_messages(paging_options)
      |> limit(^paging_options.page_size)

    select_repo(@api_true).all(query)
  end

  defp page_messages(query, %PagingOptions{key: nil}), do: query

  defp page_messages(query, %PagingOptions{key: {id}}) do
    from(msg in query, where: msg.message_id < ^id)
  end

  @doc """
    Retrieves a list of relayed L1 to L2 messages that have been completed.

    ## Parameters
    - `options`: A keyword list which may contain `paging_options` specifying pagination details

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.Message` representing relayed messages from L1 to L2 that have been completed.
  """
  @spec relayed_l1_to_l2_messages(paging_options: PagingOptions.t()) :: [Message.t()]
  def relayed_l1_to_l2_messages(options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      from(msg in Message,
        where: msg.direction == :to_l2 and not is_nil(msg.completion_transaction_hash),
        order_by: [desc: msg.message_id],
        limit: ^paging_options.page_size
      )

    select_repo(@api_true).all(query)
  end
end
