# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.EthBytecodeDBInterfaceTest do
  use ExUnit.Case, async: true

  alias Explorer.SmartContract.EthBytecodeDBInterface

  defp source(name, match_type), do: %{"contractName" => name, "matchType" => match_type}

  describe "process_verifier_response/2 for sources:search-all" do
    test "prefers eth-bytecode-db FULL match over sourcify PARTIAL match when alliance sources are empty" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb", "FULL")],
        "sourcifySources" => [source("sourcify", "PARTIAL")],
        "allianceSources" => []
      }

      assert {:ok, %{"contractName" => "eth_bdb", "matchType" => "FULL"} = chosen} =
               EthBytecodeDBInterface.process_verifier_response(response, [])

      refute Map.has_key?(chosen, "sourcify?")
      refute Map.has_key?(chosen, "verifier_alliance?")
    end

    test "prefers eth-bytecode-db FULL match over sourcify PARTIAL match when alliance key is absent" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb", "FULL")],
        "sourcifySources" => [source("sourcify", "PARTIAL")]
      }

      assert {:ok, %{"contractName" => "eth_bdb"}} = EthBytecodeDBInterface.process_verifier_response(response, [])
    end

    test "prefers eth-bytecode-db FULL match over alliance PARTIAL match" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb", "FULL")],
        "sourcifySources" => [source("sourcify", "PARTIAL")],
        "allianceSources" => [source("alliance", "PARTIAL")]
      }

      assert {:ok, %{"contractName" => "eth_bdb"}} = EthBytecodeDBInterface.process_verifier_response(response, [])
    end

    test "prefers sourcify FULL match over alliance and eth-bytecode-db PARTIAL matches" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb", "PARTIAL")],
        "sourcifySources" => [source("sourcify", "FULL")],
        "allianceSources" => [source("alliance", "PARTIAL")]
      }

      assert {:ok, %{"contractName" => "sourcify", "sourcify?" => true}} =
               EthBytecodeDBInterface.process_verifier_response(response, [])
    end

    test "prefers alliance FULL match over other FULL matches" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb", "FULL")],
        "sourcifySources" => [source("sourcify", "FULL")],
        "allianceSources" => [source("alliance", "FULL")]
      }

      assert {:ok, %{"contractName" => "alliance", "verifier_alliance?" => true}} =
               EthBytecodeDBInterface.process_verifier_response(response, [])
    end

    test "finds a FULL match that is not the head of the eth-bytecode-db list" do
      response = %{
        "ethBytecodeDbSources" => [source("eth_bdb_partial", "PARTIAL"), source("eth_bdb_full", "FULL")],
        "sourcifySources" => [source("sourcify", "PARTIAL")],
        "allianceSources" => []
      }

      assert {:ok, %{"contractName" => "eth_bdb_full"}} =
               EthBytecodeDBInterface.process_verifier_response(response, [])
    end

    test "falls back to PARTIAL matches in alliance, sourcify, eth-bytecode-db order" do
      assert {:ok, %{"contractName" => "alliance", "verifier_alliance?" => true}} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{
                   "ethBytecodeDbSources" => [source("eth_bdb", "PARTIAL")],
                   "sourcifySources" => [source("sourcify", "PARTIAL")],
                   "allianceSources" => [source("alliance", "PARTIAL")]
                 },
                 []
               )

      assert {:ok, %{"contractName" => "sourcify", "sourcify?" => true}} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{
                   "ethBytecodeDbSources" => [source("eth_bdb", "PARTIAL")],
                   "sourcifySources" => [source("sourcify", "PARTIAL")],
                   "allianceSources" => []
                 },
                 []
               )

      assert {:ok, %{"contractName" => "eth_bdb"}} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{
                   "ethBytecodeDbSources" => [source("eth_bdb", "PARTIAL")],
                   "sourcifySources" => [],
                   "allianceSources" => []
                 },
                 []
               )
    end

    test "returns an error when no sources were found" do
      assert {:error, :no_matched_sources} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{"ethBytecodeDbSources" => [], "sourcifySources" => [], "allianceSources" => []},
                 []
               )
    end
  end

  describe "process_verifier_response/2 for sources:search" do
    test "takes the first source" do
      assert {:ok, %{"contractName" => "first"}} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{"sources" => [source("first", "PARTIAL"), source("second", "FULL")]},
                 []
               )
    end

    test "marks the source as alliance one when only_verifier_alliance? option is set" do
      assert {:ok, %{"contractName" => "first", "verifier_alliance?" => true}} =
               EthBytecodeDBInterface.process_verifier_response(
                 %{"sources" => [source("first", "PARTIAL")]},
                 only_verifier_alliance?: true
               )
    end

    test "returns nil when there are no sources" do
      assert {:ok, nil} = EthBytecodeDBInterface.process_verifier_response(%{"sources" => []}, [])
    end
  end
end
