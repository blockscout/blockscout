defmodule BlockScoutWeb.AddressContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressContractView

  doctest BlockScoutWeb.AddressContractView

  describe "format_optimization_text/1" do
    test "returns \"true\" for the boolean true" do
      assert AddressContractView.format_optimization_text(true) == "true"
    end

    test "returns \"false\" for the boolean false" do
      assert AddressContractView.format_optimization_text(false) == "false"
    end
  end

  describe "contract_lines_with_index/1" do
    test "returns a list of tuples containing two strings each" do
      code = """
      pragma solidity >=0.4.22 <0.6.0;

      struct Proposal {
        uint voteCount;
      }

      address chairperson;
      mapping(address => Voter) voters;
      Proposal[] proposals;

      constructor(uint8 _numProposals) public {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
        proposals.length = _numProposals;
      }
      """

      result = AddressContractView.contract_lines_with_index(code)

      assert result == [
               {"pragma solidity >=0.4.22 <0.6.0;", " 1"},
               {"", " 2"},
               {"struct Proposal {", " 3"},
               {"  uint voteCount;", " 4"},
               {"}", " 5"},
               {"", " 6"},
               {"address chairperson;", " 7"},
               {"mapping(address => Voter) voters;", " 8"},
               {"Proposal[] proposals;", " 9"},
               {"", "10"},
               {"constructor(uint8 _numProposals) public {", "11"},
               {"  chairperson = msg.sender;", "12"},
               {"  voters[chairperson].weight = 1;", "13"},
               {"  proposals.length = _numProposals;", "14"},
               {"}", "15"},
               {"", "16"}
             ]
    end

    test "returns a list of tuples and the second element always has n chars with x lines" do
      chars = 3
      lines = 100
      result = AddressContractView.contract_lines_with_index(Enum.join(1..lines, "\n"))
      assert Enum.all?(result, fn {_, number} -> String.length(number) == chars end)
    end

    test "returns a list of tuples and the first element is just a line from the original string" do
      result = AddressContractView.contract_lines_with_index("a\nb\nc\nd\ne")

      assert Enum.map(result, fn {line, _number} -> line end) == [
               "a",
               "b",
               "c",
               "d",
               "e"
             ]
    end
  end
end
