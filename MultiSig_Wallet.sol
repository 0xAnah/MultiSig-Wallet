// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title Simple Multisig Wallet Contract
 * @author 0xAnah
 * @notice This contract works like a sinple mutlisig wallet
 */

contract MultiSigWallet {

//--------------------------------EVENTS---------------------------------------------//
    // This event is emitted when a deposit is made into this wallet
    event Deposited(address indexed sender, uint256 indexed value);

    // This event is emitted when an owner submmits a tranaction
    event Submitted(address indexed owner, uint256 indexed txId);

    // This event is emitted when an owner approves a transaction
    event Approved(address indexed owner, uint256 indexed  txId);

    // This event is emitted when an owner revokes its approval on a transaction
    event Revoked(address indexed owner, uint256 indexed  txId);

    // This is emitted when an owner executes the transaction
    event Execute(address indexed owner, uint256 indexed txId);


//--------------------------MODIFIERS-----------------------------------------------------//

    modifier onlyOwner() {
        // ensure msg.sender is a valid owner of this wallet
        require(isOwner[msg.sender], "Invalid Owner");
        _;
    }

    modifier txExist(uint256 txId) {
        // ensure transaction exist by checking if txId is a valid index in the transaction list
        require(txId < transactions.length, "Invalid Transaction");
        _;
    }

    modifier notApproved(uint256 txId) {
        // ensure an owner has not approved a transaction
        require(!approved[txId][msg.sender]);
        _;
    }

    modifier notExecuted(uint256 txId) {
        //ensure transaction has been executed
        require(!transactions[txId].executed);
        _;
    }



    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    // The list of all the tranactions
    Transaction[] public transactions;
    // The list of the wallet's owners
    address[] public owners;
    // a mapping between address and bool to confirm if an address is one of the wallet owner;
    mapping(address _address => bool isOwner) public isOwner;
    // a mapping between an uint and a mapping of address to boolean which represent 
    // which addresses (owners) have approved a transaction
    mapping(uint256 txId => mapping(address owner => bool approve)) public approved;
    // The  number of approvals required before a transaction can be executed;
    uint256 public immutable NUM_REQUIRED_APPROVAL;

    constructor(address[] memory _owners, uint256 _nRequiredApproval) {
        // ensure owners array is not empty;
        require(_owners.length > 0, "Multisig wallet must have owners");
        // ensure number of required approvals is not 0 and is less than or equal
        // to amount of owners
        require(_nRequiredApproval > 0 && _nRequiredApproval <= _owners.length, "");

        for(uint256 i; i < _owners.length; ++i) {
            address _owner = _owners[i];
            // ensure the zero address is listed as an owner
            require(_owner != address(0), "The zero address cannot be an owner");
            // ensure than an owner is not duplicated
            require(!isOwner[_owner], "This list contain a duplicated address");
            isOwner[_owner] = true;
            owners.push(_owner);
        }

        NUM_REQUIRED_APPROVAL = _nRequiredApproval;
    }

    /**
     * Sumbit new tx into our multisig wallet
     *
     * @param _to address that will receive the transaction
     * @param _value the amount of ETH that will transfered to the receiver
     * @param _data data passed with the tx
     */
    function submitTransaction( address _to, uint256 _value, bytes calldata _data) public onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        // The id of the newly created transaction is its index in the list of transactions
        uint256 txId = transactions.length - 1;
        approved[txId][msg.sender] = true;
        emit Submitted(msg.sender, txId);
    }

    /**
     * Approve the transaction already sumbitted, but it is waiting approvals to be executed
     *
     * @param txId transaction index in transaction array
     */
    function approve(uint256 txId) public onlyOwner txExist(txId) notApproved(txId) {
        approved[txId][msg.sender] = true;
        emit Approved(msg.sender, txId);
    }

    /**
     * Revoke that approval of the owner address (remove the approval)
     *
     * @param txId transaction index in transactions
     */
    function revoke(uint256 txId) public onlyOwner txExist(txId) notExecuted(txId) {
        approved[txId][msg.sender] = false;
        emit Revoked(msg.sender, txId);
    }

    /**
     * execute the transaction and send ETH and data of the transaction to the receiver address
     *
     * @param txId transaction index in transactions
     */
    function execute(uint256 txId) public onlyOwner txExist(txId) notExecuted(txId) {
        // ensure the transaction as enough approvals
        require(_getApprovalCount(txId) >= NUM_REQUIRED_APPROVAL, "Number of approval not enough");
        Transaction storage _transaction = transactions[txId];

        (bool success,) = _transaction.to.call{value: _transaction.value}(_transaction.data);
        require(success, "Transaction failed");

        emit Execute(msg.sender, txId);
    }


    /**
     * Get the number of approvals if the transaction id
     *
     * @param txId transaction index in transactions
     */
    function _getApprovalCount(uint256 txId) private view returns(uint256 totalApprovalCount) {

        for(uint256 i; i < owners.length; ++i) {
            address _owner = owners[i];
            if(approved[txId][_owner]) {
                ++totalApprovalCount;
            }
        }
    }

    /**
     * Handle receiving ETH from external wallets
     */
    receive() external payable { 
        emit Deposited(msg.sender, msg.value);
    }

}