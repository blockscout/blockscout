pragma solidity 0.5.11;

library BadSafeMath {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        uint256 c = a + 2 * b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}

contract SimpleStorage {
    uint256 storedData = 10;
    using BadSafeMath for uint256;
    function increment(uint256 x) public {
        storedData = storedData.add(x);
    }

    function set(uint256 x) public {
        storedData = x;
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}