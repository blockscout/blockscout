# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.VerificationStatus do
  @moduledoc """
  Represents single verification try
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Solidity.PublisherWorker, as: SolidityPublisherWorker
  alias Que.Persistence, as: QuePersistence

  @typedoc """
  * `contract_address_hash` - address of the contract which was tried to verify
  * `status` - try status: :pending | :pass | :fail
  * `uid` - unique verification try identifier
  """
  @primary_key false
  typed_schema "smart_contract_verification_statuses" do
    field(:uid, :string, primary_key: true, null: false)
    field(:status, :integer, null: false)
    field(:contract_address_hash, Hash.Address, null: false)

    timestamps()
  end

  @required_fields ~w(uid status contract_address_hash)a

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    casted_params = encode_status(params)

    struct
    |> cast(casted_params, @required_fields)
    |> validate_required(@required_fields)
  end

  def encode_status(%{status: status} = changeset) do
    case status do
      :pending ->
        Map.put(changeset, :status, 0)

      :pass ->
        Map.put(changeset, :status, 1)

      :fail ->
        Map.put(changeset, :status, 2)

      _ ->
        changeset
    end
  end

  def encode_status(changeset), do: changeset

  def decode_status(number) when number in [0, 1, 2, 3] do
    case number do
      0 ->
        :pending

      1 ->
        :pass

      2 ->
        :fail

      3 ->
        :unknown_uid
    end
  end

  def insert_status(uid, status, address_hash) do
    {:ok, hash} = if is_binary(address_hash), do: Chain.string_to_address_hash(address_hash), else: address_hash

    %__MODULE__{}
    |> changeset(%{uid: uid, status: status, contract_address_hash: hash})
    |> Repo.insert()
  end

  def update_status(uid, status) do
    __MODULE__
    |> Repo.get_by(uid: uid)
    |> changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Marks every pending (`status = 0`) verification attempt for the given address as passed (`status = 1`).

  This reconciles status rows that were left pending because the verification worker
  never reached `update_status/2` — e.g. it raised after inserting the pending row, or
  the contract was ultimately verified via a path that does not write this table (API
  v2, UI, Sourcify, eth_bytecode_db, Verifier Alliance). It is meant to be called
  whenever a smart contract becomes verified through any path.

  ## Parameters
  - `address_hash`: The address of the verified contract, as an `Explorer.Chain.Hash.Address`
    struct or a `0x`-prefixed string. `nil` or an unparsable value is treated as a no-op.

  ## Returns
  - `{number_of_updated_rows, nil}`: the number of pending rows that were marked as passed.
  """
  @spec set_pending_statuses_to_passed(Hash.Address.t() | binary() | nil) :: {non_neg_integer(), nil}
  def set_pending_statuses_to_passed(address_hash) do
    case normalize_address_hash(address_hash) do
      {:ok, hash} ->
        now = DateTime.utc_now()

        __MODULE__
        |> where([vs], vs.contract_address_hash == ^hash and vs.status == 0)
        |> Repo.update_all(set: [status: 1, updated_at: now])

      :error ->
        {0, nil}
    end
  end

  @doc """
  Marks the verification attempt as failed (`status = 2`) unless it is already resolved.

  Used when the verification attempt failed or its job crashed. The row is inserted if the
  job crashed before inserting the pending one. A row that is already resolved (e.g. set
  to passed by `set_pending_statuses_to_passed/1` because the contract got verified via
  another path meanwhile) is left untouched.

  ## Parameters
  - `uid`: The unique identifier of the verification attempt.
  - `address_hash`: The address of the contract being verified, as an
    `Explorer.Chain.Hash.Address` struct or a `0x`-prefixed string.

  ## Returns
  - `{:ok, t()}` or `{:error, Ecto.Changeset.t()}` as returned by `Repo.insert/2`. When the
    row is already resolved and left untouched, the returned struct doesn't reflect the
    stored status.
  """
  @spec set_failed_if_pending(String.t(), Hash.Address.t() | binary()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def set_failed_if_pending(uid, address_hash) do
    now = DateTime.utc_now()

    %__MODULE__{}
    |> changeset(%{uid: uid, status: :fail, contract_address_hash: address_hash})
    |> Repo.insert(
      on_conflict: from(vs in __MODULE__, where: vs.status == 0, update: [set: [status: 2, updated_at: ^now]]),
      conflict_target: :uid,
      # the conditional update above skips resolved rows, which is not an error here
      allow_stale: true
    )
  end

  defp normalize_address_hash(%Hash{} = hash), do: {:ok, hash}
  defp normalize_address_hash(address_hash) when is_binary(address_hash), do: Chain.string_to_address_hash(address_hash)
  defp normalize_address_hash(_), do: :error

  def fetch_status(uid) do
    case validate_uid(uid) do
      {:ok, valid_uid} ->
        __MODULE__
        |> Repo.get_by(uid: valid_uid)
        |> (&if(is_nil(&1), do: 3, else: Map.get(&1, :status))).()
        |> decode_status()
        |> mb_find_uid_in_queue(uid)

      _ ->
        :unknown_uid
    end
  end

  def generate_uid(address_hash) do
    case Chain.string_to_address_hash(address_hash) do
      :error ->
        nil

      {:ok, %Hash{byte_count: 20, bytes: address_hash}} ->
        address_encoded = Base.encode16(address_hash, case: :lower)
        timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(16) |> String.downcase()
        address_encoded <> timestamp
    end
  end

  def validate_uid(<<_address::binary-size(40), timestamp_hex::binary>> = uid) do
    case Integer.parse(timestamp_hex, 16) do
      {timestamp, ""} ->
        if DateTime.utc_now() |> DateTime.to_unix() >= timestamp do
          {:ok, uid}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def validate_uid(_), do: :error

  defp mb_find_uid_in_queue(:unknown_uid, uid) do
    SolidityPublisherWorker
    |> QuePersistence.all()
    |> Enum.find_value(fn
      %Que.Job{arguments: {"flattened_api", _, _, ^uid}} ->
        :pending

      %Que.Job{arguments: {"json_api", _, _, ^uid}} ->
        :pending

      _ ->
        nil
    end) || :unknown_uid
  end

  defp mb_find_uid_in_queue(other_status, _), do: other_status
end
