# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.DeleteUnmatchedCloneWithImmutableArgumentsImplementations do
  @moduledoc """
  Deletes cached `clone_with_immutable_arguments` proxy implementations of contracts whose bytecode
  doesn't match the whole clone runtime code.

  The wighawag variant used to be detected by the beginning of the bytecode only, so such rows could
  be stored for contracts which don't delegate to the stored implementation. A cached row is served
  until it is refetched, and is kept when the refetch fails, so the rows rejected by the current
  matcher are removed. The remaining rows of this type are left intact; deleted ones are resolved
  again on demand.

  The conditions mirror `Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments`.
  """
  use Ecto.Migration

  def up do
    execute(~S"""
    DELETE FROM proxy_implementations AS proxy_implementation
    USING addresses AS address
    WHERE proxy_implementation.proxy_type = 'clone_with_immutable_arguments'
      AND address.hash = proxy_implementation.proxy_address_hash
      AND (
        -- wighawag variant
        (
          substring(address.contract_code FROM 1 FOR 9) = '\x3d3d3d3d363d3d3761'::bytea
          AND substring(address.contract_code FROM 10 FOR 2) = substring(address.contract_code FROM 18 FOR 2)
          AND substring(address.contract_code FROM 12 FOR 6) = '\x603736393661'::bytea
          AND substring(address.contract_code FROM 20 FOR 3) = '\x013d73'::bytea
          AND substring(address.contract_code FROM 43 FOR 13) = '\x5af43d3d93803e603557fd5bf3'::bytea
        )
        -- solady variant
        OR (
          substring(address.contract_code FROM 1 FOR 10) = '\x363d3d373d3d3d363d73'::bytea
          AND substring(address.contract_code FROM 31 FOR 13) = '\x5af43d3d93803e602a57fd5bf3'::bytea
        )
      ) IS NOT TRUE
    """)
  end

  def down, do: :ok
end
