# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.UserOperation.RawV06 do
  @moduledoc """
  Raw user operation data for EntryPoint v0.6.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    title: "UserOperationRawV06",
    description: "Raw user operation data v0.6.",
    type: :object,
    properties: %{
      sender: General.AddressHash,
      nonce: General.IntegerString,
      init_code: General.HexData,
      call_data: General.HexData,
      call_gas_limit: General.IntegerString,
      verification_gas_limit: General.IntegerString,
      pre_verification_gas: General.IntegerString,
      max_fee_per_gas: General.IntegerString,
      max_priority_fee_per_gas: General.IntegerString,
      paymaster_and_data: General.HexData,
      signature: General.HexData
    },
    required: [
      :sender,
      :nonce,
      :init_code,
      :call_data,
      :call_gas_limit,
      :verification_gas_limit,
      :pre_verification_gas,
      :max_fee_per_gas,
      :max_priority_fee_per_gas,
      :paymaster_and_data,
      :signature
    ],
    nullable: false,
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Proxy.AccountAbstraction.UserOperation.RawV07ToV09 do
  @moduledoc """
  Raw user operation data for EntryPoint v0.7 through v0.9.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General

  OpenApiSpex.schema(%{
    title: "UserOperationRawV07ToV09",
    description: "Raw user operation data v0.7-v0.9.",
    type: :object,
    properties: %{
      sender: General.AddressHash,
      nonce: General.IntegerString,
      init_code: General.HexData,
      call_data: General.HexData,
      account_gas_limits: General.FullHash,
      pre_verification_gas: General.IntegerString,
      gas_fees: General.FullHash,
      paymaster_and_data: General.HexData,
      signature: General.HexData
    },
    required: [
      :sender,
      :nonce,
      :init_code,
      :call_data,
      :account_gas_limits,
      :pre_verification_gas,
      :gas_fees,
      :paymaster_and_data,
      :signature
    ],
    nullable: false,
    additionalProperties: false
  })
end
