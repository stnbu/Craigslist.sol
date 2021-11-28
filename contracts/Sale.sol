pragma solidity ^0.5.0;

contract Sale {

    // This conract represents a "sale" in the real world.
    //
    // But it must have data to represent the various "terms" of the sale.
    //
    // For this, it only wants a `sale_hash`. A `sale_hash` could be computed with
    // something like, in pseudocode:
    //
    // let sale_hash = hash({
    //   bytes32: sale_hash,
    //   bytes32: item_hash,
    //   uint: price
    // });
    //
    // The input can be anything at all! It only has meaning to the buyer and seller.
    // They both sign this hash! [tbd]
    //
    // If an escrower intervenes and asks to "see the sale", _either_ the buyer or the
    // seller can reveal this. If neither choose to reveal it (for some reason) it can
    // in theory remain a secret to even the escrower.
    //
    // By signing [tbd] the `sale_hash`...
    //   * The buyer proclaims: "I know what I am buying and I know the asking price."
    //   * The seller proclaims: "This is the thing that I show buyers and here is the
    //     asking price. It's obvious!"
    //
    // If there is some call for it, we can even find a way to prove that the seller signed it first.
    // That would eliminate: Buyer signs a self-serving sale hash, gets seller drunk (in-person) and
    // convinces her to do the same. Showing that the seller has the first-known signature of the
    // `sale_hash` would support a claim by the buyer that the seller was the sale's /author/.
    // Note that this can all happen independant of this contract. If the escrower calls for such
    // proof, the buyer and seller may or may not have arranged for this. Escrower just knows: sale_hash

    // The `sale_hash` can indeed be random data! To every other party, it's just xxx bits of data
    // until/unless revealed.

    enum State {
	DEPLOYED,
	STARTED,
	ACCEPTED,
	FINALIZED,
    };

    bytes32 public sale_hash;
    address public seller_address;
    address public buyer_address;
    uint public offer;
    State public state;

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

    function contructor() {
	state = State.OPEN;
    }

    // This could be `constructor` but that kind of breaks some symmetry: some 3rd party
    // deployed this contract ...let's pretend ...for no particular reason.
    function startSale(bytes32 _sale_hash, address _seller_address, uint _offer)
	public payable requireState(State.DEPLOYED) {
	// Wait... we want a signature of the sale_hash by the buyer. Isn't this the
	// time to "collect it"? Wait! By calling this function, the buyer is literally
	// signing the sale_hash...! (right?)
	sale_hash = _sale_hash;
	seller_address = _seller_address;
	buyer_address = msg.sender;
	offer = _offer;
	state = State.STARTED
    }

    // there is no decrementOffer! It's impossible on purpose.
    function incrementOffer(uint increase)
	public payable requireState(State.STARTED) buyerOnly() {
	offer += increase;
    }

    function acceptCurrentOffer() public requireState(State.STARTED) sellerOnly() {
	// When the seller calls this function, it means: Seller has agreed to everything and will
	// now transfer "the item" (e.g. put it in box and ship it.)
	//
	// Race condition?
	// What if the offer is incremented after the seller last sees it but before this gets called?
	// Maybe the buyer is responsible for not letting that happen..?
	state = State.ACCEPTED;
    }

    function finalize() public requireState(State.ACCEPTED) buyerOnly() {
	// When the buyer calls this it means: I have custody of "the item" OR I give up!
	state = State.FINALIZED;
    }
}
