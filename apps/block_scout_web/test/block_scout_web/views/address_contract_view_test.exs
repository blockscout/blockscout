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
               {"/**", " 1"},
               {"* Submitted for verification at blockscout.com on ", " 2"},
               {"*/", " 3"},
               {"pragma solidity >=0.4.22 <0.6.0;", " 4"},
               {"", " 5"},
               {"struct Proposal {", " 6"},
               {"  uint voteCount;", " 7"},
               {"}", " 8"},
               {"", " 9"},
               {"address chairperson;", "10"},
               {"mapping(address => Voter) voters;", "11"},
               {"Proposal[] proposals;", "12"},
               {"", "13"},
               {"constructor(uint8 _numProposals) public {", "14"},
               {"  chairperson = msg.sender;", "15"},
               {"  voters[chairperson].weight = 1;", "16"},
               {"  proposals.length = _numProposals;", "17"},
               {"}", "18"},
               {"", "19"}
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
               "/**",
               "* Submitted for verification at blockscout.com on ",
               "*/",
               "a",
               "b",
               "c",
               "d",
               "e"
             ]
    end
  end
end
