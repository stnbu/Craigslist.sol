pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract SignalSale {
    // After deploying this contract:
    //
    // 1) Buyer starts a sale with a pre-arranged "sale hash" and the seller's
    // address as input. The value sent to `start` must be twice the intended
    // offer: half becomes the offer and the other half becomes he buyer's
    // deposit.
    // 2) After the sale is started...
    //   a) Seller calls `approve` sending their deposit, which must equal the
    //      offer. Calling `approve` means the seller intends to transfer
    //      (e.g. ship) the item being sold.
    //   b) Or, the buyer calls `cancel` for a full refund at any time before
    //      seller calls `approve`.
    // 3) The buyer calls `finalize`, along with their "signal hash". By calling
    // `finalize` the buyer is indicating that the item has been received OR
    //  they have given up on the seller ever coming through. `signal_hash` is
    // `keccak256(abi.encodePacked(salt, signal, happy))` where,
    //   * `salt` is some random bytes (which must be retained by the buyer!)
    //   * `signal` is a positive integer to be "burned" as a signal. This is
    //      the signal's "magnitude".
    //   * `happy` is a boolean, This is the signal's "sign": happy means the
    //     `signal` goes to seller. Not happy means the `signal` gets _burned_
    //     (goes to the zero address.)
    // 4) The seller calls `sellerSignals`. This is mandatory and is the only
    // opportunity the seller will have to set the signal. The format, reasoning
    // and arithmetic for the seller's "signal hash" is the same as for the
    // buyer.
    // 5) The buyer and seller _both_ call `reveal`, which reveals and records
    // their signals. This is done after the sale is "finalized" and both have
    // permanently recorded their signal hash so neither is able to change their
    // signal to punish the other for an "unjust signal".
    // 6) The buyer and seller both call `withdraw`, which permits them to
    // withdraw funds, after adjustments for "signaling".

    // Important:
    //
    // When either party chooses a `signal` greater than zero, that money is
    // _taken from them_! Participants in "nominal" sales are incentivized to
    // set `signal=0`, which renders `happy` meaningless and maximizes their
    // outcomes.
    //
    // On first impression, it may seems absurd for a user to voluntarily give
    // up some of their deposit, especially if it is simply burnt, but imagine a
    // few scenarios:
    //
    // Example:
    //
    // You are buying a $200 guitar from a seller who has 2000 sales and no
    // unhappy signals. Most of these sales were made in the last year, some of
    // them for large amounts of money. All signs point to this being a safe
    // bet. After all, it's only a $200 guitar. Seems like a reasonable bet.
    //
    // Suppose you go through with this sale and it becomes apparent that this
    // user clearly acts unfairly and it's apparent (somehow) that you simply
    // just got ripped off by this sparkling clean user... what would you do?
    //
    // Would you swear off the system forever? What if the last 300 sales of
    // this seller were all $200 guitars and all ended with no unhappies and
    // they were all in the last month. Why would you be hesitant? You can trust
    // the values on the system because they are all signed by the relevant
    // keys.
    //
    // You can even examine the balance of buyers' wallets at the time of sale
    // to get a gauge on how "big" the players are. You can also examine the
    // reputation of these buyers.  An experienced, reputable buyer that
    // understands how the system works would not hesitate to signal unhappy to
    // some extent if they were screwed over a $200 guitar.
    //
    // You have no recourse. There is nothing else you can do but vote with a
    // few of you $200 (which you laid down as a deposit when you called
    // `start`.) And obviously, for you, `happy != true`, so you choose to be
    // the first of 2001 sales to cast a negative vote and significantly ding
    // this seller's reputation. BAM! You burn $5 in the direction of this
    // newly-sketchy seller.
    //
    // Not only does this hurt the seller, but many purchases down the road, it
    // becomes clear that you are a good-faith actor. That penalty increases in
    // value in proportion to your reputation.

    enum State {
        NOT_STARTED,
        STARTED,
        ACCEPTED,
        FINALIZED,
        SIGNALED,
        CANCELED
    }

    // There is an implicit `deposit` member for both buyer and seller. We don't
    // track it because it's understood To be exactly equal to "offer" and
    // required by both.
    struct Participant {
        address payable _address;
        bool revealed;
        uint signal;
        bool happy;
        bytes32 signal_hash;
        bytes32 salt;
        int balance; // Signed because we need to allow negative balance
                      // (before withdrawl at which point it must be >=0 or we
                      // have broken logic.)
    }

    struct Sale {
        uint offer;
        State state;
        Participant buyer;
        Participant seller;
    }

    uint constant BOND = 100; // pretty cheap!

    mapping(bytes32 => Sale) private sales;

    enum BondStatus {
        NEVER_BONDED,
        CURRENTLY_BONDED,
        LAPSED // "WAS_BONDED"??
    }

    mapping(address => BondStatus) private bonds;

    function start(bytes32 sale_hash, address payable seller_address) public
        payable {

        uint available = msg.value;
        require(bonds[msg.sender] != BondStatus.LAPSED);
        if (bonds[msg.sender] == BondStatus.NEVER_BONDED) {
            if (msg.value < BOND) {
                revert();
            }
            available -= BOND;
            bonds[msg.sender] = BondStatus.CURRENTLY_BONDED;
        }

        require(available % 2 == 0);
        require(sales[sale_hash].state == State.NOT_STARTED);

        Sale memory sale; // "memory" creates zero values, "storage" does not.
                          // also, we assign to the global storage `sales` at
                          // the end...! Ok...?
        sale.offer = available / 2;
        sale.state = State.STARTED;

        Participant memory buyer;
        buyer._address = payable(msg.sender);
        buyer.happy = true;
        sale.buyer = buyer;

        Participant memory seller;
        seller._address = seller_address;
        seller.happy = true;
        sale.seller = seller;
        sales[sale_hash] = sale;
    }

    function accept(bytes32 sale_hash) public payable {
        uint available = msg.value;
        require(bonds[msg.sender] != BondStatus.LAPSED);
        if (bonds[msg.sender] == BondStatus.NEVER_BONDED) {
            if (msg.value < BOND) {
                revert();
            }
            available -= BOND;
            bonds[msg.sender] = BondStatus.CURRENTLY_BONDED;
        }
        Sale storage sale = sales[sale_hash];
        require(sale.seller._address == msg.sender);
        require(sale.state == State.STARTED);
        require(sale.offer == available);
        // The seller has an _implicit_ deposit, by the rules of the game. No
        // need to track.
        sale.state = State.ACCEPTED;
    }

    function finalize(bytes32 sale_hash, bytes32 signal_hash) public {
        Sale storage sale = sales[sale_hash];
        require(sale.buyer._address == msg.sender);
        require(sale.state == State.ACCEPTED);
        sale.state = State.FINALIZED;
        sale.buyer.signal_hash = signal_hash;
    }

    function cancel(bytes32 sale_hash) public {
        require(sales[sale_hash].buyer._address == msg.sender);
        require(sales[sale_hash].state == State.STARTED);
        // These should be impossible. We leave them in as suspenders.
        assert(sales[sale_hash].seller.balance == 0);

        Sale memory sale = sales[sale_hash];
        sale.state = State.CANCELED;
        sale.buyer.balance = int(sales[sale_hash].offer * 2);
        sales[sale_hash] = sale;
    }

    function sellerSignals(bytes32 sale_hash, bytes32 signal_hash) public {
        Sale memory sale = sales[sale_hash];
        require(sale.seller._address == msg.sender);
        require(sale.state == State.FINALIZED);
        sale.seller.signal_hash = signal_hash;
        sale.state = State.SIGNALED;
        sales[sale_hash] = sale;
    }

    function thisParticipant(Sale memory sale) private
        returns (Participant memory) {
        if (sale.buyer._address == msg.sender) {
            return sale.buyer;
        } else if (sale.seller._address == msg.sender) {
            return sale.seller;
        } else {
            revert();
        }
    }

    function otherParticipant(Sale memory sale) private
        returns (Participant memory) {
        if (sale.buyer._address == msg.sender) {
            return sale.seller;
        } else if (sale.seller._address == msg.sender) {
            return sale.buyer;
        } else {
            revert();
        }
    }

    function reveal(bytes32 sale_hash, bytes32 salt, uint signal, bool happy)
        public {
        // FIXME: see https://docs.soliditylang.org/en/v0.8.9/abi-spec.html
        // "Warning: If you use ...encodePacked"
        Sale memory sale = sales[sale_hash];
        require(sale.state == State.SIGNALED);


        Participant memory caller = thisParticipant(sale);

        require(caller.signal_hash ==
                keccak256(abi.encodePacked(salt, signal, happy)));
        caller.revealed = true;
        caller.signal = signal;
        caller.happy = happy;

        Participant memory other = otherParticipant(sale);

        caller.balance -= int(signal);
        if (sale.buyer._address == msg.sender) {
            // due to the SELLER: offer + her deposit
            other.balance += int(sale.offer * 2);
        } else if (sale.seller._address == msg.sender) {
            // due to the BUYER: his deposit only
            other.balance += int(sale.offer);
        } else {
            revert();
        }
        if (caller.happy) {
            other.balance += int(signal);
        }
        sales[sale_hash] = sale;
    }

    function withdraw(bytes32 sale_hash) public {
        Sale memory sale = sales[sale_hash];
        require(
                ((sale.state == State.SIGNALED) &&
                 (sale.seller.revealed && sale.buyer.revealed))
                ||
                (sale.state == State.CANCELED));
        Participant memory caller = thisParticipant(sale);
        Participant memory other = otherParticipant(sale);
        if (!other.happy) {
            payable(address(0)).transfer(other.signal);
        }
        // until we can rule it out...
        assert(caller.balance >= 0);
        uint to_caller = uint(caller.balance);
        caller.balance = 0;
        caller._address.transfer(to_caller);
        sales[sale_hash] = sale;
    }

    function withdrawBond() public {
        require (bonds[msg.sender] == BondStatus.CURRENTLY_BONDED);
        bonds[msg.sender] = BondStatus.LAPSED;
        payable(msg.sender).transfer(BOND);
    }

    // These are ugly! `sales` and `bonds` want to be "private". We need getters in order to read them in tests.
    function _sale(bytes32 sale_hash) public returns (Sale memory) { return sales[sale_hash]; }
    function _bond(address _address) public returns (BondStatus) { return bonds[_address]; }
}

// ## Stuff that was on the top but now is on the bottom:
//
// [gigantic hole] There is nothing stopping e.g. a seller from writing a bot to
// pump their ratings without end. Ooops? Might need another turtle.
//
// [gigantic putty] If n% of both ends' deposit got _burned_ every time, that
// would be a dial that could be adjusted up or down. Got to burn coal to prove
// you created bitcoin => got to burn ether to prove that you are /on/ this
// system. Ethereum has this concept built in: gas. If we have a concept of
// "overall commitment" requiring actors to burn some Wei in order to
// participate, we would filter out (for the right position of "dial")
// participants that want to use spam techniques to bump their reputation. They
// have to pay gas costs to do this, but how sure can we be that this is enough?
// Is there a mechanism that could 'dial this in' automatically.
//
// AND BY THE WAY, burning 90000 Wei with each transaction would be a lot
// cheaper than the overhead you pay indirectly for e.g. eBay.
//
// [more putty] Also, the reputation of the buyer wallets in a spamming
// situation would have to be taken into account. There could be all kinds of
// methods to determine if participant is a botnet: do the wallets get their
// value from the same wallets? If you grab a selection of wallets the seller
// clams were legitimate sales, what is their _simultaneous_ balance when the
// sale took place? In other words: if a single seller is using subterfuge to
// make fake sales look like real sales, You should be able to do enough
// sampling and "analysis" to figure out if all these auto-created drone wallets
// shared the same _actual money_. If you have a million dollars, you can make
// two 500k wallets appear at the same time, you can make two million dollar
// wallets appear, _but not at the same time_.  The wallets of the claimed
// "buyers" are subject to this analysis. Maybe.
//
// TBD:
//
// * What about [escrow](https://youtu.be/OZmO_7JBeao)?
// * All data for all sales are traceable, but this data is not stored in a
// particularly efficient way from the "traceability" point of view. This is
// intentional: contracts should be very terse and efficient. The work required
// to go through _millions_ of sales in this contract is minuscule for a single
// server that has access to the blockchain. In production, a process (on a
// server) will need to calculate helpful metrics for future prospective buyers
// and sellers. After extraction from this contract's on-chain storage, e.g. a
// website can present helpful metrics on a per-buyer or per-seller basis (pie
// charts, graphs, smileys, ratios, factors...)
// * A "client" for interacting with this contract.
// * A whole horde of users. Addresses that have participated in many sales will
// have a meaningful reputation. For example, a "good" seller might be one with
// 1000 sales, all where the buyer has burned zero. A _great_ seller might be
// someone with 10,000 sales with no burned (unhappy) signals and an average of
// 200 Wei in "happy" signals per sale (ad infinitum). If there are sellers on
// this system with a positive happy signal and zero negative signal and have
// 800 sales, then that user is probably a better bet than Beanies003@eBay
// (imho).
// * A way to carry "reputation" with you but still leaving your original
// identity behind. Not required, but would be cool.
