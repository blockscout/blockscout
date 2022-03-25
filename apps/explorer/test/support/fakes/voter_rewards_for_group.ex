defmodule Explorer.Fakes.VoterRewardsForGroup do
  @group_address_1_hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  }
  @group_address_2_hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
  }

  @voter_address_1_hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  }
  @voter_address_2_hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
  }

  @block_1_number 10_696_320
  @block_1_hash %Explorer.Chain.Hash{
    byte_count: 32,
    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  }
  @block_2_number 10_713_600
  @block_2_hash %Explorer.Chain.Hash{
    byte_count: 32,
    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
  }
  @block_3_number 10_730_880
  @block_3_hash %Explorer.Chain.Hash{
    byte_count: 32,
    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3>>
  }
  @block_4_number 10_748_160
  @block_4_hash %Explorer.Chain.Hash{
    byte_count: 32,
    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4>>
  }
  @block_5_number 10_765_440
  @block_5_hash %Explorer.Chain.Hash{
    byte_count: 32,
    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5>>
  }

  def calculate(voter_address_hash, group_address_hash, _to_date)
      when group_address_hash == @group_address_1_hash and
             voter_address_hash == @voter_address_1_hash do
    %{
      group: group_address_hash,
      total: 350,
      rewards: [
        %{
          amount: 80,
          block_hash: @block_1_hash,
          block_number: @block_1_number,
          date: ~U[2022-01-01 17:42:43.162804Z],
          epoch_number: 619
        },
        %{
          amount: 20,
          block_hash: @block_2_hash,
          block_number: @block_2_number,
          date: ~U[2022-01-02 17:42:43.162804Z],
          epoch_number: 620
        },
        %{
          amount: 75,
          block_hash: @block_3_hash,
          block_number: @block_3_number,
          date: ~U[2022-01-03 17:42:43.162804Z],
          epoch_number: 621
        },
        %{
          amount: 31,
          block_hash: @block_4_hash,
          block_number: @block_4_number,
          date: ~U[2022-01-04 17:42:43.162804Z],
          epoch_number: 622
        },
        %{
          amount: 77,
          block_hash: @block_5_hash,
          block_number: @block_5_number,
          date: ~U[2022-01-05 17:42:43.162804Z],
          epoch_number: 623
        }
      ]
    }
  end

  def calculate(voter_address_hash, group_address_hash, _to_date)
      when group_address_hash == @group_address_1_hash and
             voter_address_hash == @voter_address_2_hash do
    %{
      group: group_address_hash,
      total: 175,
      rewards: [
        %{
          amount: 78,
          block_hash: @block_5_hash,
          block_number: @block_5_number,
          date: ~U[2022-01-05 17:42:43.162804Z],
          epoch_number: 623
        }
      ]
    }
  end

  def calculate(voter_address_hash, group_address_hash, _to_date)
      when group_address_hash == @group_address_1_hash and
             voter_address_hash == @voter_address_2_hash do
    %{
      group: group_address_hash,
      total: 175,
      rewards: [
        %{
          amount: 78,
          block_hash: @block_5_hash,
          block_number: @block_5_number,
          date: ~U[2022-01-05 17:42:43.162804Z],
          epoch_number: 623
        }
      ]
    }
  end

  def calculate(_voter_address_hash, group_address_hash, _to_date) when group_address_hash == @group_address_2_hash do
    %{
      group: group_address_hash,
      total: 175,
      rewards: [
        %{
          amount: 39,
          block_hash: @block_4_hash,
          block_number: @block_4_number,
          date: ~U[2022-01-04 17:42:43.162804Z],
          epoch_number: 622
        },
        %{
          amount: 78,
          block_hash: @block_5_hash,
          block_number: @block_5_number,
          date: ~U[2022-01-05 17:42:43.162804Z],
          epoch_number: 623
        }
      ]
    }
  end
end
