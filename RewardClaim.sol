// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title RewardClaim — Merkle-proof reward claims, run in rounds by the owner.
/// Each round the owner publishes a Merkle root over (address, amount) leaves.
/// Anyone on the list claims their own amount once per round by presenting a
/// proof; the claimer pays gas, the contract pays out of its funded inventory.
/// Round 1: flat 1,000 LNB for every JAGENT epoch 1-4 buyer wallet.
/// Round 2 (later): flat presale-participation bonus for list members who also
/// bought in the presale. Unclaimed tokens return to the owner after a round's
/// deadline via withdrawUnclaimed().
contract RewardClaim {
    IERC20 public immutable token;
    address public immutable owner;

    uint256 public currentRound; // 0 = no round yet
    bytes32 public merkleRoot;
    uint256 public roundDeadline; // claims close at this timestamp
    bool public roundOpen;

    mapping(uint256 => mapping(address => bool)) public claimed;

    event RoundStarted(uint256 indexed round, bytes32 root, uint256 deadline);
    event RoundClosed(uint256 indexed round);
    event Claimed(uint256 indexed round, address indexed claimer, uint256 amount);
    event UnclaimedWithdrawn(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _token, address _owner) {
        require(_token != address(0) && _owner != address(0), "addr=0");
        token = IERC20(_token);
        owner = _owner;
    }

    /// @notice Owner opens a new round with a fresh Merkle root and a deadline
    /// `durationSeconds` from now. Any previous round must be closed or expired.
    function startRound(bytes32 _root, uint256 _durationSeconds) external onlyOwner {
        require(!roundOpen || block.timestamp > roundDeadline, "round still open");
        require(_root != bytes32(0) && _durationSeconds > 0, "bad params");
        currentRound += 1;
        merkleRoot = _root;
        roundDeadline = block.timestamp + _durationSeconds;
        roundOpen = true;
        emit RoundStarted(currentRound, _root, roundDeadline);
    }

    /// @notice Owner closes the current round early.
    function closeRound() external onlyOwner {
        require(roundOpen, "no open round");
        roundOpen = false;
        emit RoundClosed(currentRound);
    }

    function claimable() public view returns (bool) {
        return roundOpen && block.timestamp <= roundDeadline;
    }

    /// @notice Claim your reward for the current round.
    /// @param amount Your entitled amount (in the Merkle leaf).
    /// @param proof Merkle proof for leaf keccak256(abi.encode(you, amount)).
    function claim(uint256 amount, bytes32[] calldata proof) external {
        require(claimable(), "claims closed");
        require(!claimed[currentRound][msg.sender], "already claimed");
        bytes32 leaf = keccak256(abi.encode(msg.sender, amount));
        require(_verify(proof, merkleRoot, leaf), "invalid proof");
        claimed[currentRound][msg.sender] = true;
        require(token.transfer(msg.sender, amount), "transfer failed");
        emit Claimed(currentRound, msg.sender, amount);
    }

    /// @notice After a round is closed or expired, owner reclaims the
    /// contract's remaining token balance.
    function withdrawUnclaimed() external onlyOwner {
        require(!claimable(), "round still claimable");
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "nothing left");
        require(token.transfer(owner, bal), "transfer failed");
        emit UnclaimedWithdrawn(bal);
    }

    function _verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 p = proof[i];
            hash = hash < p ? keccak256(abi.encodePacked(hash, p)) : keccak256(abi.encodePacked(p, hash));
        }
        return hash == root;
    }
}
