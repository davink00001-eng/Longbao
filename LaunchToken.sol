// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LaunchToken — fixed-supply ERC-20, no admin functions.
/// The entire supply is minted once, in the constructor, to `recipient`.
/// There is no owner, no mint, no burn, no pause, no blacklist: after
/// deployment nobody (including the deployer) can change anything.
contract LaunchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint256 _totalSupply, address _recipient) {
        require(_recipient != address(0), "recipient=0");
        require(_totalSupply > 0, "supply=0");
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[_recipient] = _totalSupply;
        emit Transfer(address(0), _recipient, _totalSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "to=0");
        require(balanceOf[from] >= value, "balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
