defmodule BlockScoutWeb.API.V2.ValidatorControllerTest do
  use BlockScoutWeb.ConnCase

  if Application.compile_env(:explorer, :chain_type) == :stability do
    alias Explorer.Chain.Address
    alias Explorer.Chain.Cache.StabilityValidatorsCounters
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
      assert json["blocks_validated_count"] == count + 1
      assert compare_item(validator, json)
    end

    describe "/validators/stability" do
      test "get paginated list of the validators", %{conn: conn} do
        validators =
          insert_list(51, :validator_stability)
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
            validator = insert(:validator_stability)
            blocks_count = Enum.random(0..50)

            _ =
              for _ <- 0..blocks_count do
                insert(:block, miner_hash: validator.address_hash, miner: nil)
              end

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
            validator = insert(:validator_stability)
            blocks_count = Enum.random(0..50)

            _ =
              for _ <- 0..blocks_count do
                insert(:block, miner_hash: validator.address_hash, miner: nil)
              end

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

        StabilityValidatorsCounters.consolidate()
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
end
