defmodule BlockScoutWeb.API.V2.ValidatorControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :stability do
    alias Explorer.Chain.Address
    alias Explorer.Chain.Cache.Counters.Stability.ValidatorsCount
    alias Explorer.Chain.Stability.Validator, as: ValidatorStability
    alias Explorer.Helper

    defp check_paginated_response(first_page_resp, second_page_resp, list) do
      assert Enum.count(first_page_resp["items"]) == 50
      assert first_page_resp["next_page_params"] != nil
      compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
      compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

      assert Enum.count(second_page_resp["items"]) == 1
      assert second_page_resp["next_page_params"] == nil
      compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
    end

    defp compare_default_sorting_for_asc({validator_1, blocks_count_1}, {validator_2, blocks_count_2}) do
      case {
        Helper.compare(blocks_count_1, blocks_count_2),
        Helper.compare(
          Keyword.fetch!(ValidatorStability.state_enum(), validator_1.state),
          Keyword.fetch!(ValidatorStability.state_enum(), validator_2.state)
        ),
        Helper.compare(validator_1.address_hash.bytes, validator_2.address_hash.bytes)
      } do
        {:lt, _, _} -> false
        {:eq, :lt, _} -> false
        {:eq, :eq, :lt} -> false
        _ -> true
      end
    end

    defp compare_default_sorting_for_desc({validator_1, blocks_count_1}, {validator_2, blocks_count_2}) do
      case {
        Helper.compare(blocks_count_1, blocks_count_2),
        Helper.compare(
          Keyword.fetch!(ValidatorStability.state_enum(), validator_1.state),
          Keyword.fetch!(ValidatorStability.state_enum(), validator_2.state)
        ),
        Helper.compare(validator_1.address_hash.bytes, validator_2.address_hash.bytes)
      } do
        {:gt, _, _} -> false
        {:eq, :lt, _} -> false
        {:eq, :eq, :lt} -> false
        _ -> true
      end
    end

    defp compare_item(%ValidatorStability{} = validator, json) do
      assert Address.checksum(validator.address_hash) == json["address"]["hash"]
      assert to_string(validator.state) == json["state"]
    end

    defp compare_item({%ValidatorStability{} = validator, count}, json) do
      assert compare_item(validator, json)
      assert json["blocks_validated_count"] == count
    end

    describe "/validators/stability" do
      test "get paginated list of the validators", %{conn: conn} do
        validators =
          51
          |> insert_list(:validator_stability)
          |> Enum.sort_by(
            fn validator ->
              {Keyword.fetch!(ValidatorStability.state_enum(), validator.state), validator.address_hash.bytes}
            end,
            :desc
          )

        request = get(conn, "/api/v2/validators/stability")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/validators/stability", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, validators)
      end

      test "sort by blocks_validated asc", %{conn: conn} do
        validators =
          for _ <- 0..50 do
            blocks_count = Enum.random(0..50)
            validator = insert(:validator_stability, blocks_validated: blocks_count)

            {validator, blocks_count}
          end
          |> Enum.sort(&compare_default_sorting_for_asc/2)

        init_params = %{"sort" => "blocks_validated", "order" => "asc"}
        request = get(conn, "/api/v2/validators/stability", init_params)
        assert response = json_response(request, 200)

        request_2nd_page =
          get(conn, "/api/v2/validators/stability", Map.merge(init_params, response["next_page_params"]))

        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, validators)
      end

      test "sort by blocks_validated desc", %{conn: conn} do
        validators =
          for _ <- 0..50 do
            blocks_count = Enum.random(0..50)
            validator = insert(:validator_stability, blocks_validated: blocks_count)

            {validator, blocks_count}
          end
          |> Enum.sort(&compare_default_sorting_for_desc/2)

        init_params = %{"sort" => "blocks_validated", "order" => "desc"}
        request = get(conn, "/api/v2/validators/stability", init_params)
        assert response = json_response(request, 200)

        request_2nd_page =
          get(conn, "/api/v2/validators/stability", Map.merge(init_params, response["next_page_params"]))

        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, validators)
      end

      test "state_filter=probation", %{conn: conn} do
        insert_list(51, :validator_stability, state: Enum.random([:active, :inactive]))

        validators =
          insert_list(51, :validator_stability, state: :probation)
          |> Enum.sort_by(
            fn validator ->
              {Keyword.fetch!(ValidatorStability.state_enum(), validator.state), validator.address_hash.bytes}
            end,
            :desc
          )

        init_params = %{"state_filter" => "probation"}

        request = get(conn, "/api/v2/validators/stability", init_params)
        assert response = json_response(request, 200)

        request_2nd_page =
          get(conn, "/api/v2/validators/stability", Map.merge(init_params, response["next_page_params"]))

        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, validators)
      end
    end

    describe "/validators/stability/counters" do
      test "get counters", %{conn: conn} do
        _validator_active1 =
          insert(:validator_stability, state: :active, inserted_at: DateTime.add(DateTime.utc_now(), -2, :day))

        _validator_active2 = insert(:validator_stability, state: :active)
        _validator_active3 = insert(:validator_stability, state: :active)

        _validator_inactive1 =
          insert(:validator_stability, state: :inactive, inserted_at: DateTime.add(DateTime.utc_now(), -2, :day))

        _validator_inactive2 = insert(:validator_stability, state: :inactive)
        _validator_inactive3 = insert(:validator_stability, state: :inactive)

        _validator_probation1 =
          insert(:validator_stability, state: :probation, inserted_at: DateTime.add(DateTime.utc_now(), -2, :day))

        _validator_probation2 = insert(:validator_stability, state: :probation)
        _validator_probation3 = insert(:validator_stability, state: :probation)

        ValidatorsCount.consolidate()
        :timer.sleep(500)

        percentage = (3 / 9 * 100) |> Float.floor(2)
        request = get(conn, "/api/v2/validators/stability/counters")

        assert %{
                 "active_validators_counter" => "3",
                 "active_validators_percentage" => ^percentage,
                 "new_validators_counter_24h" => "6",
                 "validators_counter" => "9"
               } = json_response(request, 200)
      end
    end
  end

  if @chain_type == :zilliqa do
    alias Explorer.Chain.Zilliqa.Staker
    alias Explorer.Chain.Zilliqa.Hash.BLSPublicKey
    alias Explorer.Chain.Cache.BlockNumber

    @page_limit 50

    # A helper to verify the JSON structure for a single validator.
    # Adjust the expectations based on what your prepare functions return.
    defp check_validator_json(%Staker{} = validator, json) do
      assert json["peer_id"] == validator.peer_id
      assert json["added_at_block_number"] == validator.added_at_block_number
      assert json["stake_updated_at_block_number"] == validator.stake_updated_at_block_number
      assert json["control_address"]["hash"] |> String.downcase() == validator.control_address_hash |> to_string()
      assert json["reward_address"]["hash"] |> String.downcase() == validator.reward_address_hash |> to_string()
      assert json["signing_address"]["hash"] |> String.downcase() == validator.signing_address_hash |> to_string()
    end

    describe "GET /api/v2/validators/zilliqa" do
      test "returns a paginated list of validators", %{conn: conn} do
        total_validators = @page_limit + 1
        # Insert enough validators to force pagination.
        for _ <- 1..total_validators do
          insert(:zilliqa_staker)
        end

        # First page request.
        request = get(conn, "/api/v2/validators/zilliqa")
        first_page = json_response(request, 200)

        # Verify that the view returns the expected keys.
        assert is_list(first_page["items"])
        assert Map.has_key?(first_page, "next_page_params")

        # # Check that the first page contains the page limit number of items.
        assert length(first_page["items"]) == @page_limit

        # Second page request using next_page_params.
        request = get(conn, "/api/v2/validators/zilliqa", first_page["next_page_params"])
        second_page = json_response(request, 200)

        # Since we inserted one more than the page limit, the second page should have one item
        # and no further page.
        assert length(second_page["items"]) == total_validators - @page_limit
        assert second_page["next_page_params"] == nil
      end
    end

    test "returns only active stakers", %{conn: conn} do
      staker = insert(:zilliqa_staker)
      insert(:zilliqa_staker, balance: 0)
      insert(:zilliqa_staker, added_at_block_number: 2 ** 31 - 1)

      bls_key = to_string(staker.bls_public_key)
      index = staker.index
      balance = to_string(staker.balance)

      request = get(conn, "/api/v2/validators/zilliqa", %{"filter" => "active"})

      assert %{
               "items" => [
                 %{
                   "bls_public_key" => ^bls_key,
                   "index" => ^index,
                   "balance" => ^balance
                 }
               ]
             } = json_response(request, 200)
    end

    describe "GET /api/v2/validators/zilliqa/:bls_public_key" do
      test "returns validator details for a valid BLS public key", %{conn: conn} do
        # Insert a validator and get its BLS public key as a string.
        validator = insert(:zilliqa_staker)
        bls_public_key_str = to_string(validator.bls_public_key)

        conn = get(conn, "/api/v2/validators/zilliqa/#{bls_public_key_str}")
        response = json_response(conn, 200)

        # The view for "zilliqa_validator.json" returns a map with extra keys.
        assert is_map(response)
        check_validator_json(validator, response)
      end

      test "returns an error for an invalid BLS public key", %{conn: conn} do
        invalid_bls_key = "invalid_key"

        conn = get(conn, "/api/v2/validators/zilliqa/#{invalid_bls_key}")
        response = json_response(conn, 400)

        # The controller returns a 400 with a JSON message for an invalid BLS public key.
        assert response["message"] == "Invalid bls public key"
      end
    end
  end
end
