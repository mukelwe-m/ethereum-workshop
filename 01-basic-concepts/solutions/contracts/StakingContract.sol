// SPDX-License-Identifier: MIT
// compiler version must be greater than or equal to 0.8.26 and less than 0.9.0
pragma solidity >=0.8.26 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

// Contract to demonstrate Solidity basics
contract StakingContract {
    // Variables
    address public immutable owner;

    enum Ethnicity {
        African,
        European,
        Asian
    }

    // Struct
    struct User {
        string name;
        uint8 age;
        Ethnicity ethnicity;
        uint256 balance;
        uint256 index;
        bool exists;
    }

    /**
        Mappings in Solidity (mapping(address => uint256)) do not have a built-in way to check if a key exists 
            because all possible keys default to their zero value if not explicitly set.
        You can use an additional boolean mapping to track whether a key has been set
     */
    mapping(address => User) public users;
    // Array with dynamic size
    address[] public userAddresses;

    // Constants
    // uint256 public constant MAX_PEOPLE = 10;
    uint256 public immutable MAX_PEOPLE = 10;
    bytes32 constant SLOT = 0;

    // Events
    event NumberUpdated(uint256 oldNumber, uint256 newNumber);
    // Indexed parameters help you filter the logs by the indexed parameter
    event UserAdded(
        address indexed account,
        string name,
        uint8 age,
        uint256 balance
    );
    event UserWithdrew(
        address indexed account,
        string name,
        uint8 age,
        uint256 balance
    );
    // Log of the contract
    event Log(string func, uint256 gas);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        // Underscore is a special character only used inside
        // a function modifier and it tells Solidity to
        // execute the rest of the code.
        _;
    }

    // Lock implemented using transient state
    modifier lock() {
        assembly {
            if tload(SLOT) {
                revert(0, 0)
            }
            tstore(SLOT, 1)
        }
        _;
        assembly {
            tstore(SLOT, 0)
        }
    }

    // Constructor
    constructor(address _owner, uint256 _max_people) {
        owner = _owner;
        MAX_PEOPLE = _max_people;
    }

    // Fallback function must be declared as external.
    fallback() external payable {
        // send / transfer (forwards 2300 gas to this fallback function)
        // call (forwards all of the gas)
        emit Log("fallback", gasleft());
    }

    // Receive is a variant of fallback that is triggered when msg.data is empty
    receive() external payable {
        emit Log("receive", gasleft());
    }

    /**
        Get the age of the calling address after x years
     */
    function getAge(uint8 _years) public view returns (uint8) {
        User memory user = users[msg.sender];
        user.age = user.age + _years;
        return user.age;
    }

    // Pure function
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        // sum and overflow are local variables
        // it might result in overflow; use SafeMath library
        (bool overflow, uint256 sum) = Math.tryAdd(a, b);
        require(!overflow, "Addition has resulted in an overflow :(");
        return sum;
    }

    // Payable function with struct
    function addUser(
        string memory _name,
        uint8 _age,
        Ethnicity ethnicity
    ) public payable {
        // msg.sender is a global variable
        require(!users[msg.sender].exists, "User already exists");
        require(msg.value > 0, "The staking value is 0");
        require(
            userAddresses.length < MAX_PEOPLE,
            string.concat(
                "Users are over the limit of ",
                Strings.toString(MAX_PEOPLE)
            )
        );

        // the object is created in memory then stored in storage
        User memory user = User(
            _name,
            _age,
            ethnicity,
            msg.value,
            userAddresses.length,
            true
        );

        // store the reference pointer
        users[msg.sender] = user;
        userAddresses.push(msg.sender);

        emit UserAdded(msg.sender, _name, _age, msg.value);
    }

    // Return many
    function userDetails(
        address _address
    ) public view returns (string memory name, uint8 age) {
        User memory user = users[_address];
        return (user.name, user.age);
    }

    /**
     * Function that allows the users to withdraw all the Ether they deposited the contract
     */
    function withdraw() external lock {
        uint256 amount = users[msg.sender].balance;
        string memory name = users[msg.sender].name;
        require(amount > 0, "No balance to withdraw");

        console.log(string.concat(name, " <-> withdrawing "));

        // Send funds before updating balance
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        _delete(msg.sender);
    }

    function _delete(address userAddress) internal {
        if (!users[msg.sender].exists) {
            return;
        }

        User memory user = users[userAddress];

        // Update of the state happens after sending Ether
        delete users[msg.sender]; // resets value to 0

        // shifted user
        address shiftedUserAddress = userAddresses[userAddresses.length - 1];
        User storage shiftedUser = users[shiftedUserAddress];

        userAddresses[user.index] = shiftedUserAddress;
        shiftedUser.index = user.index;

        // Remove last element
        userAddresses.pop();
    }

    // Internal function
    function _internalFunction() internal pure returns (string memory) {
        return "Internal function called";
    }
}

/**
    Inheritance
    List in order of most base-like to most derived
 */
contract ExtendedSolidity is StakingContract {
    constructor(
        address owner,
        uint256 _max_people
    ) StakingContract(owner, _max_people) {}

    // New function in derived contract
    function getInternalFunctionResult() public pure returns (string memory) {
        return _internalFunction();
    }
}
