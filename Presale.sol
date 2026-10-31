// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title Presale — fixed-rate BNB presale with instant token delivery.
/// Buyers send BNB and immediately receive tokens from the contract's
/// funded inventory. Every BNB accepted is forwarded in the same
/// transaction to `fundsWallet`; the contract never holds raised funds.
/// Oversubscribed payments (past the hard cap, the per-wallet max, or the
/// remaining inventory) are partially filled and the excess is refunded in
/// the same transaction. The owner (fundsWallet) starts the sale, can end
/// it early, and can withdraw unsold tokens once it has ended.
contract Presale {
    IERC20 public immutable token;
    address public immutable fundsWallet; // also the owner
    uint256 public immutable tokensPerBNB; // whole tokens per 1 BNB
    uint256 public immutable hardCapWei;
    uint256 public immutable minBuyWei;
    uint256 public immutable maxBuyWeiPerWallet;
    uint256 public immutable durationSeconds;

    uint256 public startTime; // 0 = not started
    uint256 public endTime;
    bool public closedEarly;
    uint256 public totalRaised;
    mapping(address => uint256) public contributions;

    bool private _locked;

    event Started(uint256 startTime, uint256 endTime);
    event Buy(address indexed buyer, uint256 bnbAccepted, uint256 bnbRefunded, uint256 tokensOut);
    event ClosedEarly();
    event UnsoldWithdrawn(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == fundsWallet, "not owner");
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "reentrant");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address _token,
        address _fundsWallet,
        uint256 _tokensPerBNB,
        uint256 _hardCapWei,
        uint256 _minBuyWei,
        uint256 _maxBuyWeiPerWallet,
        uint256 _durationSeconds
    ) {
        require(_token != address(0) && _fundsWallet != address(0), "addr=0");
        require(_tokensPerBNB > 0 && _hardCapWei > 0 && _durationSeconds > 0, "bad params");
        require(_maxBuyWeiPerWallet == 0 || _maxBuyWeiPerWallet >= _minBuyWei, "max<min");
        token = IERC20(_token);
        fundsWallet = _fundsWallet;
        tokensPerBNB = _tokensPerBNB;
        hardCapWei = _hardCapWei;
        minBuyWei = _minBuyWei;
        maxBuyWeiPerWallet = _maxBuyWeiPerWallet;
        durationSeconds = _durationSeconds;
    }

    function started() public view returns (bool) {
        return startTime != 0;
    }

    function ended() public view returns (bool) {
        return started() && (closedEarly || block.timestamp > endTime || totalRaised >= hardCapWei);
    }

    function active() public view returns (bool) {
        return started() && !ended() && block.timestamp >= startTime && block.timestamp <= endTime;
    }

    /// @notice Owner starts the sale window. Can only be called once.
    function start() external onlyOwner {
        require(startTime == 0, "already started");
        startTime = block.timestamp;
        endTime = block.timestamp + durationSeconds;
        emit Started(startTime, endTime);
    }

    /// @notice Owner ends the sale immediately.
    function close() external onlyOwner {
        require(active(), "not active");
        closedEarly = true;
        emit ClosedEarly();
    }

    function buy() public payable nonReentrant {
        require(active(), "not active");
        require(msg.value >= minBuyWei, "below min");

        uint256 accepted = msg.value;

        // Per-wallet max.
        if (maxBuyWeiPerWallet > 0) {
            uint256 room = maxBuyWeiPerWallet > contributions[msg.sender]
                ? maxBuyWeiPerWallet - contributions[msg.sender]
                : 0;
            require(room >= minBuyWei, "wallet max reached");
            if (accepted > room) accepted = room;
        }

        // Hard cap.
        uint256 capRoom = hardCapWei - totalRaised;
        if (accepted > capRoom) accepted = capRoom;

        // Remaining inventory (tokensPerBNB whole tokens per 1 BNB, both 18dp:
        // tokenWei out = bnbWei * tokensPerBNB).
        uint256 inventory = token.balanceOf(address(this));
        uint256 maxByInventory = inventory / tokensPerBNB;
        if (accepted > maxByInventory) accepted = maxByInventory;
        require(accepted >= minBuyWei, "sold out");

        uint256 refund = msg.value - accepted;
        uint256 tokensOut = accepted * tokensPerBNB;

        // Effects first.
        totalRaised += accepted;
        contributions[msg.sender] += accepted;

        // Forward the raise to the funds wallet — never held here.
        (bool okFunds, ) = fundsWallet.call{value: accepted}("");
        require(okFunds, "funds forward failed");

        if (refund > 0) {
            (bool okRefund, ) = msg.sender.call{value: refund}("");
            require(okRefund, "refund failed");
        }

        require(token.transfer(msg.sender, tokensOut), "token transfer failed");
        emit Buy(msg.sender, accepted, refund, tokensOut);
    }

    receive() external payable {
        buy();
    }

    /// @notice After the sale has ended, owner reclaims unsold inventory.
    function withdrawUnsold() external onlyOwner {
        require(ended(), "not ended");
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "nothing left");
        require(token.transfer(fundsWallet, bal), "transfer failed");
        emit UnsoldWithdrawn(bal);
    }
}
