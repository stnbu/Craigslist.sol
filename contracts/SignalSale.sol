pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract SignalSale {

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
        uint balance;
    }

    struct Sale {
        uint offer;
        State state;
        Participant buyer;
        Participant seller;
    }

    mapping(bytes32 => Sale) public sales;

    function start(bytes32 sale_hash, address payable seller_address) public
	payable {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.state == State.NOT_STARTED, "Sale already started.");
        require(msg.value % 2 == 0, "Value sent must be divisible by two.");
        this_sale.offer = msg.value / 2;
        this_sale.state = State.STARTED;

        Participant storage buyer;
        buyer._address = msg.sender;
        buyer.happy = true;
        this_sale.buyer = buyer;

        Participant storage seller;
        seller._address = seller_address;
        seller.happy = true;
        this_sale.seller = seller;
    }

    function accept(bytes32 sale_hash) public payable {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.seller._address == msg.sender);
        require(this_sale.state == State.STARTED);
        require(this_sale.offer == msg.value);
        // The seller has an _implicit_ deposit, by the rules of the game. No
        // need to track.
        this_sale.state = State.ACCEPTED;
    }

    function finalize(bytes32 sale_hash, bytes32 signal_hash) public {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.buyer._address == msg.sender);
        require(this_sale.state == State.ACCEPTED);
        this_sale.state = State.FINALIZED;
        this_sale.buyer.signal_hash = signal_hash;
    }

    function cancel(bytes32 sale_hash) public {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.buyer._address == msg.sender);
        require(this_sale.state == State.STARTED);
        // These should be impossible. We leave them in as suspenders.
        assert(this_sale.seller.balance == 0);
        assert(this_sale.offer == address(this).balance);
        this_sale.state = State.CANCELED;
        this_sale.buyer.balance = address(this).balance;
    }

    function sellerSignals(bytes32 sale_hash, bytes32 signal_hash) public {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.seller._address == msg.sender);
        require(this_sale.state == State.FINALIZED);
        this_sale.buyer.signal_hash = signal_hash;
        this_sale.state = State.SIGNALED;
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

    function reveal(bytes32 sale_hash, uint salt, uint signal, bool happy)
	public {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.state == State.SIGNALED);
        Participant memory caller = thisParticipant(this_sale);
        require(caller.signal_hash ==
                keccak256(abi.encodePacked(salt, signal, happy)));
        caller.revealed = true;
        caller.signal = signal;
        caller.happy = happy;

        Participant memory other = otherParticipant(this_sale);
        if (caller.happy) {
            other.balance = this_sale.offer / 2 + signal;
        } else {
            other.balance = this_sale.offer / 2;
        }
    }

    function withdraw(bytes32 sale_hash) public {
        Sale storage this_sale = sales[sale_hash];
        require(this_sale.state == State.SIGNALED);
        require(this_sale.seller.revealed && this_sale.buyer.revealed);
        Participant memory caller = thisParticipant(this_sale);
        Participant memory other = otherParticipant(this_sale);
        if (!other.happy) {
            address(0).transfer(other.signal);
        }
        uint to_caller = caller.balance;
        caller.balance = 0;
        caller._address.transfer(to_caller);
    }
}
