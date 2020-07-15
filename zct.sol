pragma solidity ^0.4.25;
/**
* Math operations with safety checks
*/
library SafeMath {
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        require(a == b * c + a % b);
        return c;
    }
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c>=a && c>=b);
        return c;
    }
}

contract ZCT {
    using SafeMath for uint256;
    string public name = "ZCT";
    string public symbol = "ZCT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 0;
    address public owner;
    bool public paused;

    /* This creates an array with all balances */
    mapping (address => uint256) public balanceTokenOf; // accounts token balance
    mapping (address => uint256) public freezeOf; // self freeze token balance
    mapping (address => bool) public lockAccountOf; // contract owner lock account
    mapping (address => uint256) public lockTokenOf; // contract owner lock account's token balance
    mapping (address => mapping (address => uint256)) public allowance;

    /* This generates a public event on the blockchain that will notify clients
    */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event BatchTransfer(address indexed from, address[] indexed receivers, uint256[] values);
    /* This generates a public event on the blockchain that will notify clients
    */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    /* This notifies clients about the amount frozen */
    event Freeze(address indexed from, uint256 value);
    /* This notifies clients about the amount unfrozen */
    event Unfreeze(address indexed from, uint256 value);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /* Initializes contract with initial supply tokens to the creator of the
    contract */
    constructor() public {
        owner = msg.sender;
        paused = false;
    }
    /* Send coins */
    function transfer(address _to, uint256 _value) public returns (bool success)
    {
        require(!paused);
        // lock all transfer in critical situation
        require(!lockAccountOf[msg.sender], "the sender is lock");
        // need the sender is unlock
        require(_to != 0x0);
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_value > 0);
        // Check value
        require(balanceTokenOf[msg.sender] >= _value);
        // Check if the sender has enough
        require(balanceTokenOf[_to] + _value >= balanceTokenOf[_to]);
        // Check for overflows
        require(balanceTokenOf[_to] + _value >= _value);
        // Check for overflows
        require(balanceTokenOf[msg.sender] >= lockTokenOf[msg.sender]);
        // Check for lock
        require(balanceTokenOf[msg.sender] >= lockTokenOf[msg.sender] + _value);
        // Check for lock
        balanceTokenOf[msg.sender] = SafeMath.safeSub(balanceTokenOf[msg.sender], _value);
        // Subtract from the sender
        balanceTokenOf[_to] = SafeMath.safeAdd(balanceTokenOf[_to], _value);
        // Add the same to the recipient

        emit Transfer(msg.sender, _to, _value);
        // Notify anyone listening that this transfer took place
        return true;
    }

    function batchTransfer(address[] _receivers, uint256[] _values, uint256 _total_value, uint _len) public returns (bool) {
        require(!paused);
        require(!lockAccountOf[msg.sender], "the sender is lock");
        require(balanceTokenOf[msg.sender] >= _total_value);
        require(balanceTokenOf[msg.sender] >= lockTokenOf[msg.sender]);
        require(balanceTokenOf[msg.sender] >= lockTokenOf[msg.sender] + _total_value);

        for(uint i=0; i<_len; i++){
            require(_receivers[i] != address(0), "ERC20: mint to the zero address");
            require(_values[i] > 0);
            require(balanceTokenOf[_receivers[i]] + _values[i] >= balanceTokenOf[_receivers[i]]);
            require(balanceTokenOf[_receivers[i]] + _values[i] >= _values[i]);

            balanceTokenOf[msg.sender] = balanceTokenOf[msg.sender].safeSub(_values[i]);
            balanceTokenOf[_receivers[i]] = balanceTokenOf[_receivers[i]].safeAdd(_values[i]);
        }

        emit BatchTransfer(msg.sender, _receivers, _values);
        return true;
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require((_value == 0) || (allowance[msg.sender][_spender] == 0));
        // Only Reset, not allowed to modify
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(!paused);
        // lock all transfor in critical situation cases
        require(!lockAccountOf[msg.sender], "the sender is lock");
        // need the sender is unlock
        require(_to != address(0));
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_value > 0);
        // Check Value
        require(balanceTokenOf[_from] >= _value);
        // Check if the sender has enough
        require(balanceTokenOf[_to] + _value > balanceTokenOf[_to]);
        // Check for overflows
        require(balanceTokenOf[_to] + _value > _value);
        // Check for overflows
        require(allowance[_from][msg.sender] >= _value);
        // Check allowance
        require(balanceTokenOf[_from] >= lockTokenOf[_from]);
        // Check for lock
        require(balanceTokenOf[_from] >= lockTokenOf[_from] + _value);
        // Check for lock
        balanceTokenOf[_from] = SafeMath.safeSub(balanceTokenOf[_from], _value);
        // Subtract from the sender
        balanceTokenOf[_to] = SafeMath.safeAdd(balanceTokenOf[_to], _value);
        // Add the same to the recipient
        allowance[_from][msg.sender] = SafeMath.safeSub(allowance[_from][msg.sender], _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function freeze(uint256 _value) public returns (bool success) {
        require(_value > 0);
        require(balanceTokenOf[msg.sender] >= _value);
        // Check if the sender has enough
        require(freezeOf[msg.sender] + _value >= freezeOf[msg.sender]);
        // Check for Overflows
        require(freezeOf[msg.sender] + _value >= _value);
        // Check for Overflows
        balanceTokenOf[msg.sender] = SafeMath.safeSub(balanceTokenOf[msg.sender], _value);
        // Subtract from the sender
        freezeOf[msg.sender] = SafeMath.safeAdd(freezeOf[msg.sender], _value);
        // Updates totalSupply
        emit Freeze(msg.sender, _value);
        return true;
    }

    function unfreeze(uint256 _value) public returns (bool success) {
        require(_value > 0);
        // Check Value
        require(freezeOf[msg.sender] >= _value);
        // Check if the sender has enough
        require(balanceTokenOf[msg.sender] + _value > balanceTokenOf[msg.sender]);
        // Check for Overflows
        require(balanceTokenOf[msg.sender] + _value > _value);
        // Check for overflows
        freezeOf[msg.sender] = SafeMath.safeSub(freezeOf[msg.sender], _value);
        // Subtract from the freeze
        balanceTokenOf[msg.sender] = SafeMath.safeAdd(balanceTokenOf[msg.sender], _value);
        // Add to balance
        emit Unfreeze(msg.sender, _value);
        return true;
    }

    function lockAccount(address _target) public returns (bool) {
        require(msg.sender == owner, "the sender must be the owner");
        lockAccountOf[_target] = true;
        return true;
    }

    function unlockAccount(address _target) public returns (bool) {
        require(msg.sender == owner, "the sender must be the owner");
        lockAccountOf[_target] = false;
        return true;
    }

    function mint(address receiver, uint256 amount) public  returns (bool) {
        require(!paused);
        require(msg.sender == owner, "must the owner can mint");
        require(receiver != address(0), "ERC20: mint to the zero address");

        balanceTokenOf[receiver] = balanceTokenOf[receiver].safeAdd(amount);

        totalSupply = totalSupply.safeAdd(amount);

        // emit Transfer(address(0), receiver, amount);
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        require(msg.sender == owner);
        // Only Owner
        require(_value > 0);
        // Check Value
        require(balanceTokenOf[msg.sender] >= _value);
        // Check if the sender has enough
        require(totalSupply >= _value);
        // Check for overflows
        balanceTokenOf[msg.sender] = SafeMath.safeSub(balanceTokenOf[msg.sender], _value);
        // Subtract from the sender
        totalSupply = SafeMath.safeSub(totalSupply, _value);
        // Updates totalSupply
        return true;
    }

    function lockToken(address _to, uint256 _value) public returns (bool success) {
        require(msg.sender == owner);
        // Only Owner
        require(_to != 0x0);
        // Prevent lock to 0x0 address
        //require((_value == 0) || (lockTokenOf[_to] == 0));
        // Only Reset, not allowed to modify
        require(balanceTokenOf[_to] >= _value);
        // Check for lock overflows
        lockTokenOf[_to] = _value;
        return true;
    }

    function unlockToken(address _to, uint256 _value) public returns (bool success) {
        require(msg.sender == owner);
        // Only Owner
        require(_to != 0x0);
        // Prevent lock to 0x0 address
        //require((_value == 0) || (lockTokenOf[_to] == 0));
        // Only Reset, not allowed to modify
        require(lockTokenOf[_to] >= _value);
        // Check for lock overflows
        lockTokenOf[_to] = lockTokenOf[_to].safeSub(_value);
        return true;
    }

    function pause() public returns (bool) {
        require(msg.sender == owner);
        // Only Owner
        paused = true;
        return true;
    }

    function unpause() public returns (bool) {
        require(msg.sender == owner);
        // Only Owner
        paused = false;
        return true;
    }

    function transferOwnership(address newOwner) public returns (bool) {
        require(!paused);
        require(msg.sender == owner);
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        return true;
    }

    function () public payable {
        revert();
    }
}