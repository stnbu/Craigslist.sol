pragma solidity ^0.5.0;

contract SignalSale {
    // NOTE: All these ugly `seller_foo` and `buyer_foo` variables would
    // ideally be stored in a data structure indexed by `sale_hash`. Making this
    // hopefully a "deployment of the network" rather than "a deployment of a
    // sale".
    //
    // This contract has the concept of "deposits". For PoC simplicity purposes,
    // we will assume that participation requires a deposit of 100% or more of
    // the offer amount.

    enum State {
        DEPLOYED, // Set by constructor, used as required state for start.
        STARTED,  // Buyer starts the sale.
        ACCEPTED, // Seller accepts. Means: "Seller will ship item now!"
        FINALIZED // Sale is rejected by anyone or finalized by the buyer.
    }


    bytes32 public sale_hash; // Unless revealed by participants: just data.
    address payable public seller_address;
    address payable public buyer_address;
    State public state; // Used and set by function to track state.

    // The sum of these three should equal `this.balance` at all times [TBD]
    uint public offer; // What the seller is currently agreeing to pay.
    // These are returned respectively, minus any "signal".
    uint public seller_deposit;
    uint public buyer_deposit;

    string constant DEPOSIT_TOO_SMALL =
	"Deposit must be greater than or equal to the offer.";

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

    modifier either() {
        require ((msg.sender == buyer_address) ||
		 (msg.sender == seller_address));
	_;
    }

    constructor() public {
        state = State.DEPLOYED;
    }

    // `_sale_hash` is the hash representing the sale, agreed to in advance,
    // offline by the buyer and seller. If the buyer supplies a value the seller
    // doesn't recognize/approve of, the seller may simply ignore this contract.
    //
    // `_seller_address` is the seller. The entity you have been "communicating
    // with" offline and who you expect to eventually call `accept`.
    //
    // `_deposit` means: "`_deposit` of `msg.value` is my deposit." If buyer
    // sends 3 Ether and `_deposit` is 1 Ether then `offer` becomes 2 Ether.
    function start(bytes32 _sale_hash, address payable _seller_address,
		   uint _deposit) public payable requireState(State.DEPLOYED) {
        if (_deposit * 2 < msg.value) {
            revert(DEPOSIT_TOO_SMALL);
        }
        sale_hash = _sale_hash;
        seller_address = _seller_address;
        buyer_address = msg.sender;
        buyer_deposit = _deposit;
        offer = msg.value - buyer_deposit;
        state = State.STARTED;
    }

    // The buyer may call this function to increment his offer, but only when
    // in state `STARTED`.
    //
    // `_deposit_increment` means: "`_deposit_increment` of `msg.value` is the
    // additional deposit contribution the remainder of that will increment
    // `offer`." Here we must check to ensure that the _resulting_
    // `buyer_deposit` is greater or equal to the resulting `offer`.
    function increment(uint _deposit_increment) public payable
        requireState(State.STARTED) buyerOnly() {

        if (buyer_deposit + _deposit_increment <
	    offer + msg.value - _deposit_increment) {
            revert(DEPOSIT_TOO_SMALL);
        }
        buyer_deposit += _deposit_increment;
        offer += msg.value - _deposit_increment;
    }

    // This is callable only by the seller and only when in state `STARTED`
    //
    // The value sent to this function must be greater than or equal to
    // the current offer. If so, `msg.value` becomes the seller's deposit.
    //
    // The seller would want to make a call to `offer()` in the same block
    // because by successfully calling this function, she is implicitly
    // agreeing to accept `offer`.
    function accept() public payable
        requireState(State.STARTED) sellerOnly() {

        if (msg.value < offer) {
            revert(DEPOSIT_TOO_SMALL);
        }
        seller_deposit = msg.value;
        state = State.ACCEPTED;
    }

    // There are _ONLY TWO_ participants in this sale: buyer and seller.
    // This function returns "the other one" (if b then s; if s then b)
    // and reverts if `msg.sender` is neither participant.
    function other() private returns (address payable) {
	// FIXME: do we need to inspect *_address for zeroness?
	if (msg.sender == seller_address) {
	    return buyer_address;
	} else if (msg.sender == buyer_address) {
	    return seller_address;
	} else {
	    revert("You are not part of this sale");
	}
    }

    function finalize(uint signal, bool happy) public
	requireState(State.ACCEPTED) buyerOnly() {

        state = State.FINALIZED;
	if (signal > 0) {
	    if (!happy) {
		address(0).transfer(signal);
	    } else {
		seller_address.transfer(signal);
	    }
	}
        buyer_address.transfer(buyer_deposit - signal);
        seller_address.transfer(offer + seller_deposit);
        assert(address(this).balance == 0);
    }

    // Here is the beauty: `happy` has no meaning (is undefined) if
    // `signal == 0`.
    //
    // Corollary: This means that if `signal==0` then `happy` is neutral.
    //
    // By examining `signal` and `happy` together you have three options:
    // * `signal == 0` --> I am neither happy nor unhappy
    // * `happy == true && signal == n` --> I am `n` happy
    // * `happy == false && signal == n` --> I am `n` unhappy
    //
    // And all of these are backed by the participant having sacrificed some
    // money to make the point. It also costs a tiny bit of additional gas when
    // `signal > 0`. That's traceable and could be part of future calculations
    // with regard to a participant's "reputation".
    //
    // Keep in mind that `signal=0` means the caller and the other participant
    // keep all of their money. If everyone acts in good faith, this should be
    // `0` for all but a tiny sliver of sales, about which you have actionable
    // reputation metrics. `signal > 0` should only be for exceptionally squeaky
    // wheels.
    function reject(uint signal, bool happy) public requireState(State.STARTED)
	either() {
        state = State.FINALIZED;
	uint refund;
	if (signal > 0) {
	    address payable signal_to = other();
	    if (!happy) {
		signal_to = address(0);
	    }
	    signal_to.transfer(signal);
	}
	// one thing wrong here... only one participant gets an opportunity to
	// signal.
	if (seller_address == msg.sender) {
	    seller_address.transfer(seller_deposit - signal);
	    buyer_address.transfer(offer + buyer_deposit);
	} else if (buyer_address == msg.sender) {
	    seller_address.transfer(seller_deposit);
	    buyer_address.transfer(offer + buyer_deposit - signal);
	} else {
	    revert("FIXME: we shouldn't get here. refactor.");
	}
        assert(address(this).balance == 0);
    }
}
