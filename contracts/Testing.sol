pragma solidity ^0.6.0;

contract SolidityHelpers {

    uint foo = 0;

    constructor() public {
	foo = 2;
    }
    // This lets our test automation get a calculated "signal_hash" from
    // solidity logic. Deferring how to do this correctly in python.
    function getSignalHash(bytes32 salt, uint signal, bool happy) public returns (bytes32) {
        return keccak256(abi.encodePacked(salt, signal, happy));
    }
}