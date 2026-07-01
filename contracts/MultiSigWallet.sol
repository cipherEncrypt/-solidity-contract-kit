// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MultiSigWallet
/// @notice A small M-of-N multisig. Any owner can propose a transaction; it only
///         goes through once enough owners have confirmed it. The flow is:
///         submit → confirm (by several owners) → execute.
///
/// Owners and the confirmation threshold are fixed at deploy time — keeping the
/// contract small and easy to reason about. Learning template; audit before mainnet.
contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;

    /// How many confirmations a transaction needs before it can execute.
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;

    /// txId => owner => has that owner confirmed it?
    mapping(uint256 => mapping(address => bool)) public confirmed;

    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Confirm(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx not found");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "already executed");
        _;
    }

    /// @param owners_   The signing owners. Must be non-empty and free of
    ///                  duplicates or the zero address.
    /// @param required_ Confirmations needed to execute (1..owners_.length).
    constructor(address[] memory owners_, uint256 required_) {
        require(owners_.length > 0, "owners required");
        require(required_ > 0 && required_ <= owners_.length, "bad required count");

        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            require(owner != address(0), "zero owner");
            require(!isOwner[owner], "duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }
        required = required_;
    }

    /// Accept plain ETH transfers so the wallet can be funded.
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Propose a transaction. It starts with zero confirmations.
    function submit(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 txId)
    {
        txId = transactions.length;
        transactions.push(Transaction(to, value, data, false, 0));
        emit Submit(txId);
    }

    /// @notice Add your confirmation to a pending transaction.
    function confirm(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(!confirmed[txId][msg.sender], "already confirmed");
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        emit Confirm(msg.sender, txId);
    }

    /// @notice Take back a confirmation you previously gave.
    function revoke(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(confirmed[txId][msg.sender], "not confirmed");
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        emit Revoke(msg.sender, txId);
    }

    /// @notice Execute a transaction once it has enough confirmations.
    /// @dev Marks it executed before making the call, so a re-entrant callee
    ///      can't run it twice.
    function execute(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= required, "not enough confirmations");

        txn.executed = true;
        (bool ok, ) = txn.to.call{value: txn.value}(txn.data);
        require(ok, "tx failed");

        emit Execute(txId);
    }

    /// @notice The full list of owner addresses.
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice How many transactions have ever been submitted.
    function transactionCount() external view returns (uint256) {
        return transactions.length;
    }
}
