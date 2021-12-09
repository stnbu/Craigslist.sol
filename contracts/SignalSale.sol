pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract SignalSale {
    // After deploying this contract:
    //
    // 1) Buyer starts a sale with a pre-arranged "sale hash" and the seller's
    // address as input. The value sent to `start` must be twice the intended
    // offer _plus_ a (hardcoded) bond if using the system for the first
    // time: After subtracting the bond, half of what's left becomes the "offer"
    // and the other half becomes he buyer's deposit.
    // 2) After the sale is started...
    //   a) Seller calls `approve` sending their deposit, which must equal the
    //      offer. Calling `approve` means the seller intends to transfer
    //      (e.g. ship) the item being sold.
    //   b) Or, the buyer calls `cancel` for a full refund at any time before
    //      seller calls `approve`.
    // 3) The buyer calls `finalize`, along with their "signal hash". By calling
    // `finalize` the buyer is indicating that the item has been received OR
    //  they have given up on the seller ever coming through. `signal_hash` is
    // `keccak256(abi.encodePacked(secret, signal, happy))` where,
    //   * `secret` is some random bytes (which must be retained by the buyer!)
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
        bytes32 secret;
        int balance;
    }

    struct Sale {
        uint offer;
        State state;
        Participant buyer;
        Participant seller;
    }

    uint constant BOND = 100;

    mapping(bytes32 => Sale) private sales;

    enum BondStatus {
        NEVER_BONDED,
        CURRENTLY_BONDED,
        LAPSED
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

        Sale memory sale;
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

        Sale storage sale = sales[sale_hash];
        sale.state = State.CANCELED;
        sale.buyer.balance = int(sales[sale_hash].offer * 2);
    }

    function sellerSignals(bytes32 sale_hash, bytes32 signal_hash) public {
        Sale storage sale = sales[sale_hash];
        require(sale.seller._address == msg.sender);
        require(sale.state == State.FINALIZED);
        sale.seller.signal_hash = signal_hash;
        sale.state = State.SIGNALED;
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

    function reveal(bytes32 sale_hash, bytes32 secret, uint signal, bool happy)
        public {
        Sale memory sale = sales[sale_hash];
        require(sale.state == State.SIGNALED);


        Participant memory caller = thisParticipant(sale);

        require(caller.signal_hash ==
                keccak256(abi.encodePacked(secret, signal, happy)));
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
	// wat! I never do a `sales[sale_hash].foobbar = caller`
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
