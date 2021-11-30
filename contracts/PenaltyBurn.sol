pragma solidity ^0.5.0;

contract PenaltyBurn {
    // Hello! I am a clone of `Sale` (from Sale.sol).
    // I'm just here as a starting point. I don't burn penalties just yet.

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
    bool public seller_happy;
    bool public buyer_happy;

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
        seller_happy = true;
        buyer_happy = true;
        state = State.DEPLOYED;
    }

    function startSale(bytes32 _sale_hash, address payable _seller_address)
        public payable requireState(State.DEPLOYED) {
        sale_hash = _sale_hash;
        seller_address = _seller_address;
        buyer_address = msg.sender;
        state = State.STARTED;
    }

    function incrementOffer()
        public payable requireState(State.STARTED) buyerOnly() {
    }

    function acceptCurrentOffer() public requireState(State.STARTED)
	sellerOnly() {
        state = State.ACCEPTED;
    }

    function finalize(bool happy) public requireState(State.ACCEPTED)
	buyerOnly() {
        buyer_happy = happy;
        state = State.FINALIZED;
	seller_address.transfer(address(this).balance);
    }

    function reject(bool happy) public requireState(State.STARTED) {
	if (msg.sender == buyer_address) {
	    buyer_happy = happy;
	} else if (msg.sender == seller_address) {
	    seller_happy = happy;
	} else {
	    revert();
	}
        state = State.FINALIZED;
	buyer_address.transfer(address(this).balance);
    }
}

