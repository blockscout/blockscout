# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.ScaledUIAmount do
  @moduledoc """
  Constants of [ERC-8056](https://eips.ethereum.org/EIPS/eip-8056) — Scaled UI
  Amount Extension for ERC-20 Tokens.

  On chain ERC-8056 is not a standard of its own but a display-only extension of
  ERC-20: raw balances, `totalSupply` and `Transfer` stay untouched, and the
  token merely exposes an updatable multiplier with 18 decimals of precision
  (`1e18` is `1.0`) that integrators apply when rendering amounts:

      uiAmount = rawAmount * uiMultiplier / 1e18

  It exists to represent stock splits of tokenized real-world assets without
  minting to every holder.

  Blockscout still models it as a token type of its own, `ERC-8056`, so that it
  can be filtered like any other. It is the only type that no log can reveal —
  such a token emits the plain ERC-20 `Transfer` — so it is assigned by reading
  `uiMultiplier()` off the contract instead.

  A change of the multiplier is scheduled, not instant. The contract keeps a
  triple — current value, pending value and the timestamp the pending value
  becomes effective — and `uiMultiplier()` picks between the first two by
  comparing `block.timestamp` with `effectiveAt()`. Nothing happens on chain at
  the moment a scheduled change takes effect, so there is no log to index for
  it: `Explorer.Chain.Token.effective_ui_multiplier/2` mirrors that branch
  locally instead.

  The standard is still in Draft, so all of its selectors and topics live here
  rather than being spread over the callers.
  """

  require Logger

  import Explorer.Helper, only: [decode_data: 2]

  # 01ffc9a7 = keccak256(supportsInterface(bytes4)), ERC-165
  @supports_interface_signature "01ffc9a7"
  # ERC-165 interface id of `IScaledUIAmount`: the XOR of the selectors of its
  # functions, and since `uiMultiplier()` is the only one, that selector itself
  @interface_id <<0xA6, 0x0B, 0xF1, 0x3D>>

  # a60bf13d = keccak256(uiMultiplier())
  @ui_multiplier_signature "a60bf13d"
  # dc767007 = keccak256(newUIMultiplier())
  @new_ui_multiplier_signature "dc767007"
  # 97a4064f = keccak256(effectiveAt())
  @effective_at_signature "97a4064f"

  # keccak256(UIMultiplierUpdated(uint256,uint256,uint256))
  @ui_multiplier_updated_event "0x2205df4534432b2f60654a3fdb48737ffdaf3e9edb1a498bd985bc026b15b055"
  # keccak256(TransferWithUIAmount(address,address,uint256,uint256))
  @transfer_with_ui_amount_event "0x0226a2f5c1ae0e071aeec3d4ebafcefdc5c549be11f40ed27e76e802acccf374"

  @contract_abi [
    %{
      "constant" => true,
      "inputs" => [%{"name" => "interfaceId", "type" => "bytes4"}],
      "name" => "supportsInterface",
      "outputs" => [%{"name" => "", "type" => "bool"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "uiMultiplier",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "newUIMultiplier",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "effectiveAt",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @precision Decimal.new("1000000000000000000")

  @doc """
  Applies an ERC-8056 multiplier to a raw amount, giving the amount to display.

  A `nil` multiplier leaves the amount untouched, which covers every token that
  does not implement the standard as well as an amount whose multiplier could
  not be resolved.

  Callers that hand the raw amount to a client — the API does — must not use
  this: the client needs the raw value and the multiplier separately. It exists
  for the places that render a final number themselves.
  """
  @spec scale(Decimal.t() | nil, Decimal.t() | nil) :: Decimal.t() | nil
  def scale(nil, _multiplier), do: nil
  def scale(amount, nil), do: amount

  def scale(amount, multiplier) do
    amount
    |> Decimal.new()
    |> Decimal.mult(multiplier)
    |> Decimal.div(@precision)
  end

  @doc """
  Method id of ERC-165 `supportsInterface(bytes4)`.

  The standard makes ERC-165 detection mandatory, and it is the only reliable
  way to tell an ERC-8056 token apart: a contract may well expose a function
  named `uiMultiplier()` while meaning something else entirely, and taking that
  for ERC-8056 would relabel a perfectly ordinary ERC-20.
  """
  @spec supports_interface_signature() :: String.t()
  def supports_interface_signature, do: @supports_interface_signature

  @doc """
  ERC-165 interface id of `IScaledUIAmount`, to be passed to `supportsInterface(bytes4)`.
  """
  @spec interface_id() :: binary()
  def interface_id, do: @interface_id

  @doc """
  Method id of `uiMultiplier()`, the currently effective multiplier.
  """
  @spec ui_multiplier_signature() :: String.t()
  def ui_multiplier_signature, do: @ui_multiplier_signature

  @doc """
  Method id of `newUIMultiplier()`, the multiplier scheduled to take effect at `effectiveAt()`.
  """
  @spec new_ui_multiplier_signature() :: String.t()
  def new_ui_multiplier_signature, do: @new_ui_multiplier_signature

  @doc """
  Method id of `effectiveAt()`, the Unix timestamp the pending multiplier becomes effective at.
  """
  @spec effective_at_signature() :: String.t()
  def effective_at_signature, do: @effective_at_signature

  @doc """
  Method ids of the ERC-8056 getters, in the order they are read.
  """
  @spec signatures() :: [String.t()]
  def signatures, do: [@ui_multiplier_signature, @new_ui_multiplier_signature, @effective_at_signature]

  @doc """
  First topic of `UIMultiplierUpdated(uint256,uint256,uint256)`.

  The standard requires it to be emitted on every change of the multiplier, so
  it is the trigger to re-read the getters of a token.
  """
  @spec ui_multiplier_updated_event() :: String.t()
  def ui_multiplier_updated_event, do: @ui_multiplier_updated_event

  @doc """
  First topic of `TransferWithUIAmount(address,address,uint256,uint256)`.

  Deliberately not parsed as a token transfer: the standard emits it *in
  addition to* the regular ERC-20 `Transfer`, so treating it as a transfer of
  its own would double count every movement of an ERC-8056 token. It is kept
  here to document that and to guard the behaviour with a test.
  """
  @spec transfer_with_ui_amount_event() :: String.t()
  def transfer_with_ui_amount_event, do: @transfer_with_ui_amount_event

  @doc """
  ABI of the ERC-8056 getters, to be appended to the ABI token metadata is read with.
  """
  @spec contract_abi() :: [map()]
  def contract_abi, do: @contract_abi

  @doc """
  Decodes a `UIMultiplierUpdated` log into `t:Explorer.Chain.Token.UIMultiplierChange.t/0` parameters, or returns `nil` for any other log and for one that cannot be decoded.

  All three parameters of the event are non-indexed, so a single log carries the
  whole new state of the schedule and no `eth_call` is needed to record it.
  """
  @spec parse_ui_multiplier_updated(map()) :: map() | nil
  def parse_ui_multiplier_updated(%{first_topic: @ui_multiplier_updated_event} = log),
    do: change_params(log)

  def parse_ui_multiplier_updated(_log), do: nil

  @doc """
  Same as `parse_ui_multiplier_updated/1` but without checking the topic, for a
  caller that already selected `UIMultiplierUpdated` logs — a query filtering on
  the first topic, say, where the topic is a `t:Explorer.Chain.Hash.Full.t/0`
  rather than the string this module keeps.
  """
  @spec parse_known_ui_multiplier_updated(map()) :: map() | nil
  def parse_known_ui_multiplier_updated(log), do: change_params(log)

  @doc """
  Converts the Unix timestamp `effectiveAt()` answers with into the datetime the schema stores.

  Microsecond precision is forced on purpose: `DateTime.from_unix/1` yields
  second precision, which a `:utc_datetime_usec` field rejects outright on
  `Repo.insert_all/3` — that path dumps values instead of casting them the way a
  changeset does.
  """
  @spec effective_at_from_unix(integer()) :: {:ok, DateTime.t()} | {:error, atom()}
  def effective_at_from_unix(timestamp) do
    with {:ok, effective_at} <- DateTime.from_unix(timestamp) do
      {:ok, %{effective_at | microsecond: {0, 6}}}
    end
  end

  defp change_params(log) do
    [old_multiplier, new_multiplier, effective_at_timestamp] =
      decode_data(log.data, [{:uint, 256}, {:uint, 256}, {:uint, 256}])

    case effective_at_from_unix(effective_at_timestamp) do
      {:ok, effective_at} ->
        %{
          token_contract_address_hash: log.address_hash,
          block_number: log.block_number,
          log_index: log.index,
          old_multiplier: Decimal.new(old_multiplier),
          new_multiplier: Decimal.new(new_multiplier),
          effective_at: effective_at
        }

      {:error, _reason} ->
        Logger.error(fn ->
          "Invalid effectiveAt #{effective_at_timestamp} in UIMultiplierUpdated of #{log.address_hash}"
        end)

        nil
    end
  rescue
    error ->
      Logger.error(fn ->
        [
          "Unknown UIMultiplierUpdated format: #{inspect(log)}, error: ",
          Exception.format(:error, error, __STACKTRACE__)
        ]
      end)

      nil
  end
end
