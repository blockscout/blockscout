defmodule Explorer.Chain.Celo.AggregatedElectionReward do
  @moduledoc """
  Schema for aggregated election rewards in the Celo blockchain.
  """

  use Explorer.Schema

  import Explorer.Chain.Address.Reputation, only: [reputation_association: 0]

  alias Explorer.Chain
  alias Explorer.Chain.{Token, Wei}

  alias Explorer.Chain.Celo.{ElectionReward, Epoch}

  @required_attrs ~w(epoch_number type sum count)a

  @primary_key false
  typed_schema "celo_aggregated_election_rewards" do
    field(:sum, Wei, null: false)
    field(:count, :integer, null: false)

    field(
      :type,
      Ecto.Enum,
      values: ElectionReward.types(),
      null: false,
      primary_key: true
    )

    belongs_to(:epoch, Epoch,
      primary_key: true,
      foreign_key: :epoch_number,
      references: :number,
      type: :integer
    )

    timestamps()
  end

  @spec changeset(__MODULE__.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:epoch_number)
  end

  @doc """
  Retrieves aggregated election rewards by epoch number.

  ## Parameters
  - `epoch_number` (`integer()`): The epoch number to aggregate election rewards
    for.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - A map of aggregated election rewards by type.

  ## Examples

      iex> epoch_number = 1
      iex> Explorer.Chain.Celo.AggregatedElectionReward.epoch_number_to_rewards_aggregated_by_type(epoch_number)
      %{
        voter: %{total: %Explorer.Chain.Wei{value: #Decimal<2500>}, count: 2, token: %Explorer.Chain.Token{}},
        validator: %{total: %Explorer.Chain.Wei{value: #Decimal<0>}, count: 0, token: %Explorer.Chain.Token{}},
        group: %{total: %Explorer.Chain.Wei{value: #Decimal<0>}, count: 0, token: %Explorer.Chain.Token{}},
        delegated_payment: %{total: %Explorer.Chain.Wei{value: #Decimal<0>}, count: 0, token: %Explorer.Chain.Token{}}
      }
  """
  @spec epoch_number_to_rewards_aggregated_by_type(integer(), Keyword.t()) ::
          %{atom() => %{total: Wei.t(), count: integer(), token: Token.t() | nil}}
  def epoch_number_to_rewards_aggregated_by_type(epoch_number, options \\ []) do
    reward_type_to_aggregated_rewards =
      __MODULE__
      |> where([r], r.epoch_number == ^epoch_number)
      |> Chain.select_repo(options).all()
      |> Map.new(&{&1.type, %{total: &1.sum, count: &1.count}})

    reward_type_to_token = election_reward_tokens_by_type()
    zero = %Wei{value: Decimal.new(0)}

    ElectionReward.types()
    |> Map.new(&{&1, %{total: zero, count: 0}})
    |> Map.merge(reward_type_to_aggregated_rewards)
    |> Map.new(fn {type, aggregated_reward} ->
      token = reward_type_to_token[type]
      aggregated_reward_with_token = Map.put(aggregated_reward, :token, token)
      {type, aggregated_reward_with_token}
    end)
  end

  # Retrieves the token for each type of election reward.
  #
  # ## Parameters
  # - `options` (`Keyword.t()`): Optional parameters for fetching data.
  #
  # ## Returns
  # - `%{atom() => Token.t() | nil}`: A map of reward types to token.
  #
  # ## Examples
  #
  #     iex> epoch_number = %Hash.Full{
  #     ...>   byte_count: 32,
  #     ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
  #     ...> }
  #     iex> Explorer.Chain.Celo.ElectionReward.election_reward_token_addresses_by_type(epoch_number)
  #     %{voter_reward: %Token{}, ...}
  @spec election_reward_tokens_by_type :: %{atom() => Token.t() | nil}
  defp election_reward_tokens_by_type do
    reward_type_to_token_address_hash = ElectionReward.reward_type_to_token_address_hash()

    tokens =
      reward_type_to_token_address_hash
      |> Map.values()
      |> Token.get_by_contract_address_hashes(
        api?: true,
        necessity_by_association: %{
          reputation_association() => :optional
        }
      )

    reward_type_to_token_address_hash
    |> Map.new(fn {type, address_hash} ->
      token = Enum.find(tokens, &(&1.contract_address_hash == address_hash))
      {type, token}
    end)
  end
end
