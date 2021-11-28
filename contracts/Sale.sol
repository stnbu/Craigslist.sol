pragma solidity ^0.5.0;

contract Sale {
    // IMPORTANT: This is a one-shot contract. In practice a _single_ simple contact should keep track
    // of buyer/seller/participant metrics on a per-sale basis. The other logic can be broken off
    // with different kinds of "delegation". This contract is a template for that "master" contact.
    // e.g. `buyer_happy` should be a value we can get/set for any `(sale_hash, address)` tuple.
    // Roughly speaking.

    // This contract represents a "sale" in the real world.
    //
    // But it must have data to represent the various "terms" of the sale.
    //
    // For this, it only wants a `sale_hash`. A `sale_hash` could be computed with
    // something like, in pseudocode:
    //
    // let sale_hash = hash({
    //   description: "Big Ol Green Sofa",
    //   price: 20000000000000000,
    //   currency: "wei"
    // });
    //
    // or
    //
    // let sale_hash = hash(`
    //   Please someone buy my stanky old green plush sofa!
    //   Start a sale using contract 0xCccCc..Cc and I'll probably
    //   approve any offer! I'll get your dorm number via SwarmChat. Thnxx!
    // `);
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
    // Note that this can all happen independent of this contract. If the escrower calls for such
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

    function constructor() {
	state = State.DEPLOYED;
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
	state = State.STARTED;

	// We start off with both the buyer and seller "happy".
	//
	// The next opportunity the buyer will have to set "happy" is upon his calling `finalize(bool)`.
	// Until that time, the buyer has no reason to be _unhappy_ (really?) This is the end of the sale.
	// He may _be_ unhappy, but he has no right to record it until receipt of the item or when he gives
	// up (in which case he has the right to set `happy=false`).
	//
	// The next opportunity the seller will have to set this upon her calling `reject(bool)`.
	// This can only happen if the state is STARTED. The seller may choose to abort the sale
	// at any time while it is still in state STARTED, at which time they may choose to be
	// "unhappy" (e.g. buyer is unreasonable). Otherwise, the seller will get the agreed upon
	// funds and has no real reason to be unhappy (really?).
	seller_happy = true;
	buyer_happy = true;
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
	//
	// Q: Is this too implicit? Is it obvious that the item gets shipped now? If it is in state
	// ACCEPTED, both the buyer and seller have _accepted_ that they must wrap up the sale...
	state = State.ACCEPTED;
    }

    function finalize(bool happy) public requireState(State.ACCEPTED) buyerOnly() {
	buyer_happy = happy;
	
	// When the buyer calls this it means: I have custody of "the item" OR I give up!
	state = State.FINALIZED;
    }

    function reject(bool happy) public requireState(State.STARTED) sellerOnly() {
	seller_happy = happy;

	// Somewhere in here we need to release the funds to the seller.
	
	// When the buyer calls this it means: I have custody of "the item" OR I give up!
	state = State.FINALIZED;
    }
}
