pragma solidity ^0.5.0;

contract Sale {
    // IMPORTANT: This is a one-shot contract. In practice a _single_ simple
    // contact should keep track of buyer/seller/participant metrics on a
    // per-sale basis. The other logic can be broken off with different kinds of
    // "delegation". This contract is a template for that "master" contact.
    // e.g. `buyer_happy` should be a value we can get/set for any `(sale_hash,
    // address)` tuple.  Roughly speaking.

    // This contract represents a "sale" in the real world.
    //
    // But it must have data to represent the various "terms" of the sale.
    //
    // For this, it only wants a `sale_hash`. A `sale_hash` could be computed
    // with something like, in pseudocode:
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
    //   Start a sale using contract 0xCccCc..Cc and I'll probably approve any
    //   offer! I'll get your dorm number via SwarmChat. Thnxx!
    // `);
    //
    // The input can be anything at all! It only has meaning to the buyer and
    // seller.  They both sign this hash! [tbd]
    //
    // If an escrower intervenes and asks to "see the sale", _either_ the buyer
    // or the seller can reveal this. If neither choose to reveal it (for some
    // reason) it can in theory remain a secret to even the escrower.
    //
    // By signing [tbd] the `sale_hash`...  * The buyer proclaims: "I know what
    // I am buying and I know the asking price."  * The seller proclaims: "This
    // is the thing that I show buyers and here is the asking price. It's
    // obvious!"
    //
    // If there is some call for it, we can even find a way to prove that the
    // seller signed it first.  That would eliminate: Buyer signs a self-serving
    // sale hash, gets seller drunk (in-person) and convinces her to do the
    // same. Showing that the seller has the first-known signature of the
    // `sale_hash` would support a claim by the buyer that the seller was the
    // sale's /author/.  Note that this can all happen independent of this
    // contract. If the escrower calls for such proof, the buyer and seller may
    // or may not have arranged for this. Escrower just knows: sale_hash
    //
    // The `sale_hash` can indeed be random data! To every other party, it's
    // just xxx bits of data until/unless revealed.

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

    // TBD
    uint internal blocks_to_live;
    uint internal deployed_block;

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
        // We start off with both the buyer and seller "happy".
        //
        // The next opportunity the buyer will have to set "happy" is upon his
        // calling `finalize(bool)`.  Until that time, the buyer has no reason
        // to be _unhappy_ (really?) This is the end of the sale.  He may _be_
        // unhappy, but he has no right to record it until receipt of the item
        // or when he gives up (in which case he has the right to set
        // `happy=false`).
        //
        // The next opportunity the seller will have to set this upon her
        // calling `reject(bool)`.  This can only happen if the state is
        // STARTED. The seller may choose to abort the sale at any time while it
        // is still in state STARTED, at which time they may choose to be
        // "unhappy" (e.g. buyer is unreasonable). Otherwise, the seller will
        // get the agreed upon funds and has no real reason to be unhappy
        // (really?).
        seller_happy = true;
        buyer_happy = true;
	// And we are in state "DEPLOYED" (we have to pick something. got a
	// better name?)
        state = State.DEPLOYED;

	// TBD
	blocks_to_live = 3153600; // about a year: `365 * 24 * 60 * 60 / 10` ... right?
	deployed_block = block.number;
    }

    // This could be `constructor` but that kind of breaks some symmetry: some
    // 3rd party deployed this contract ...let's pretend ...for no particular
    // reason.
    //
    // Note that there is an implicit "current offer": the contract balance.
    function startSale(bytes32 _sale_hash, address payable _seller_address)
        public payable requireState(State.DEPLOYED) {
        sale_hash = _sale_hash; // the buyer has now signed the sale_hash
        seller_address = _seller_address;
        buyer_address = msg.sender;
        state = State.STARTED;
    }

    // there is no decrementOffer! It's impossible on purpose.
    function incrementOffer()
        public payable requireState(State.STARTED) buyerOnly() {
	// The contract balance goes up. That's all for now.
    }

    function acceptCurrentOffer() public requireState(State.STARTED)
	sellerOnly() {
	// At this point, the seller has implicitly signed the sale_hash: she
	// signed the transaction for this function call on a version of this
	// contract that already had sale_hash set -- available for inspection.
	// (does this hold water?)
	//
        // When the seller calls this function, it means: Seller has agreed to
        // everything and will now transfer "the item" (e.g. put it in box and
        // ship it.)
        //
        // Race condition?  What if the offer is incremented after the seller
        // last sees it but before this gets called?  Maybe the buyer is
        // responsible for not letting that happen. Only the buyer can
        // `increment()`.
        //
        // Q: Is this too implicit? Is it obvious that the item gets shipped
        // now? If it is in state ACCEPTED, both the buyer and seller have
        // _accepted_ that they must wrap up the sale...
        state = State.ACCEPTED;
    }

    function finalize(bool happy) public requireState(State.ACCEPTED)
	buyerOnly() {
        // This function is called by the buyer to indicate "the sale is
        // complete on my end".
	//
        // When the buyer calls this it means: I have custody of "the item" OR I
        // give up!  The buyer can be happy or unhappy for any number of
        // reasons. All that is recorded is the boolean "happy" value. The buyer
        // may indeed be unhappy because the item (despite sellers pleading)
        // never arrived. These are the rules! (in this iteration) The buyer can
        // only register "unhappy". This will be the glaring exception
        // ecosystem-wide (hopes), and a seller's history should give enough
        // indication of the risk (maybe you are buying something cheap!)
        //
        // Remember: Your interactions with Amazon and Ebay have _not_ been 100%
        // happy.  If you've used these systems much, you may have a 0.5%
        // utterly-ripped-off rate.  If you see a buyer with 9000 sales and a
        // 99.5% happy rating, would you really hesitate to buy a $200 guitar
        // from this person? Such persons exist, even on Ebay.
        buyer_happy = happy;
        state = State.FINALIZED;
        // The seller gets the sales funds. If this is an un-payable contract
	// address, too bad; the sale is now finalized.
	seller_address.transfer(address(this).balance);
    }

    function reject(bool happy) public requireState(State.STARTED) {
	// This function can be called before ACCEPTED by either party. The
	// happiness is recorded as appropriate. The funds go back to the buyer
	// regardless of the caller.

	if (msg.sender == buyer_address) {
	    buyer_happy = happy;
	} else if (msg.sender == seller_address) {
	    seller_happy = happy;
	} else {
	    revert();
	}

        state = State.FINALIZED;
        // The buyer gets the sales funds. If this is an un-payable contract
	// address, too bad; the sale is now finialized.
	buyer_address.transfer(address(this).balance);
    }
}
