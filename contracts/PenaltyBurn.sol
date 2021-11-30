pragma solidity ^0.5.0;

contract PenaltyBurn {
    // NOTE: All these ugly `seller_foo` and `buyer_foo` variables would
    // ideally be stored in a data structure indexed by `sale_hash`. Making this
    // hopefully a "deployment of the network" rather than "a deployment of a
    // sale".
    //
    // This contract has the concept of "deposits". For PoC simplicity purposes,
    // we will assume that participation requires a deposit of 100% or more of
    // the offer amount.

    enum State {
        DEPLOYED,
        STARTED,
        ACCEPTED,
        FINALIZED
    }

    bytes32 public sale_hash;
    address payable public seller_address;
    address payable public buyer_address;
    State public state;
    uint public offer;
    uint public seller_deposit;
    uint public buyer_deposit;

    address payable constant ZERO_ADDRESS = address(0);

    modifier requireState(State _state) {
        require (state == _state);
        _;
    }

    modifier buyerOnly() {
        require (msg.sender == buyer_address);
        _;
    }

    modifier sellerOnly() {
        require (msg.sender == seller_address);
        _;
    }

    constructor() public {
        state = State.DEPLOYED;
    }

    function startSale(bytes32 _sale_hash, address payable _seller_address, uint _deposit)
        public payable requireState(State.DEPLOYED) {
        if (_deposit * 2 < msg.value) {
            revert();
        }
        sale_hash = _sale_hash;
        seller_address = _seller_address;
        buyer_address = msg.sender;
        buyer_deposit = _deposit;
        offer = msg.value - buyer_deposit;
        state = State.STARTED;
    }

    function incrementOffer(uint _deposit_increment) public payable
        requireState(State.STARTED) buyerOnly() {

        if (offer + msg.value - _deposit_increment <
            buyer_deposit + _deposit_increment) {
            revert();
        }
        buyer_deposit += _deposit_increment;
        offer += msg.value - _deposit_increment;
    }

    // The seller would want to make a call to `offer()` in the same block.
    function acceptCurrentOffer() public payable
        requireState(State.STARTED) sellerOnly() {

        if (msg.value < offer) {
            revert();
        }
        seller_deposit = msg.value;
        state = State.ACCEPTED;
    }

    function burnTo(uint amount, address payable _to) private {
	_to.transfer(amount);
    }

    function finalizeByBuyer(uint penalty_burn, address payable _to) public requireState(State.ACCEPTED)
        buyerOnly() {

	if ((_to != seller_address) && (_to != address(0))) {
	    revert("You may only burn to the seller or the zero address");
	}
        state = State.FINALIZED;
	burnTo(penalty_burn, _to);
        buyer_address.transfer(buyer_deposit - penalty_burn);
        seller_address.transfer(offer + seller_deposit);
        assert(address(this).balance == 0);
    }

    function rejectByBuyer(uint penalty_burn, address payable _to) public requireState(State.STARTED) buyerOnly() {
	if ((_to != seller_address) && (_to != address(0))) {
	    revert("You may only burn to the seller or the zero address");
	}
        state = State.FINALIZED;
	burnTo(penalty_burn, _to);
	buyer_address.transfer(offer + buyer_deposit - penalty_burn);
        assert(address(this).balance == 0);
    }

    function rejectBySeller(uint penalty_burn, address payable _to) public requireState(State.STARTED) sellerOnly() {
	if ((_to != buyer_address) && (_to != address(0))) {
	    revert("You may only burn to the buyer or the zero address");
	}
        state = State.FINALIZED;
	burnTo(penalty_burn, _to);
	buyer_address.transfer(seller_deposit - penalty_burn);
        assert(address(this).balance == 0);
    }
}
