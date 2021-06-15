pragma solidity 0.4.26;

contract Factory {
    address[] newContracts;

    function createContract (bytes32 name) public {
        address newContract = new ContractFromFactory(name);
        newContracts.push(newContract);
    } 
}

contract ContractFromFactory {
    bytes32 public Name;

    constructor(bytes32 name) public {
        Name = name;
    }
}