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
        if (_deposit < msg.value / 2) {
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

    function acceptCurrentOffer(uint _deposit) public payable
        requireState(State.STARTED) sellerOnly() {

        if (_deposit < offer) {
            revert();
        }
        seller_deposit = _deposit;
        state = State.ACCEPTED;
    }

    function finalize(int penalty_burn) public requireState(State.ACCEPTED)
        buyerOnly() {

        if (uint(0-penalty_burn) > buyer_deposit) {
            revert();
        }

        if (penalty_burn != 0) {
            if (penalty_burn < 0) {
                ZERO_ADDRESS.transfer(uint(0-penalty_burn));
            } else {
                seller_address.transfer(uint(penalty_burn));
            }
        }
        state = State.FINALIZED;
        seller_address.transfer(offer + seller_deposit);
        buyer_address.transfer(buyer_deposit - uint(0-penalty_burn));
        assert(address(this).balance == 0);
    }

    function reject(uint penalty_burn) public requireState(State.STARTED) {
        state = State.FINALIZED;
        if (msg.sender == buyer_address) {
            if (penalty_burn < 0) {
                ZERO_ADDRESS.transfer(uint(0-penalty_burn));
            } else if (penalty_burn > 0) {
                seller_address.transfer(penalty_burn);
            }
            seller_address.transfer(seller_deposit);
            buyer_address.transfer(offer + buyer_deposit - uint(0-penalty_burn));
        } else if (msg.sender == seller_address) {
            if (penalty_burn < 0) {
                address(ZERO_ADDRESS).transfer(0-penalty_burn);
            } else if (penalty_burn > 0) {
                buyer_address.transfer(penalty_burn);
            }
            seller_address.transfer(seller_deposit - 0-penalty_burn);
            buyer_address.transfer(offer + buyer_deposit);
        } else {
            revert();
        }
        assert(address(this).balance == 0);
    }
}
