#!/usr/bin/env python3

import pytest
import web3
from brownie import accounts, reverts, SignalSale, SolidityHelpers
from brownie.convert.datatypes import HexString, EthAddress, Wei

# State enum values. These need to account for any solidity changes.
NOT_STARTED = 0
STARTED = 1
ACCEPTED = 2
FINALIZED = 3
SIGNALED = 4
CANCELED = 5

NEVER_BONDED = 0
CURRENTLY_BONDED = 1
LAPSED = 2

def fhex(n):
    return '0x' + n.hex()

@pytest.fixture
def params():

    class ParticipantSignal(object):
        helpers = None # not 'singleton'?
        def __init__(self, hash_inputs, account):
            if ParticipantSignal.helpers is None:
                self.helpers = account.deploy(SolidityHelpers)
            self.__dict__.update(hash_inputs)
            tx = self.helpers.getSignalHash(
                self.secret,
                self.signal,
                self.happy,
                {'from': account})
            self.signal_hash = tx.return_value

    _deployer = accounts[0]
    _buyer = accounts[1]
    _seller = accounts[2]

    _buyer_signal = ParticipantSignal({
        'secret': HexString('0xb10beef', 'bytes32'),
        'signal': Wei(1),
        'happy': True
    }, _buyer)

    _seller_signal = ParticipantSignal({
        'secret': HexString('0xbadbeef', 'bytes32'),
        'signal': Wei(1),
        'happy': False
    }, _seller)

    _bond = 100

    _expected_sale = {
        'state': None,
        'offer': Wei(0), # FIXME -- factor out
        'buyer': {
            '_address': EthAddress(HexString('0x0', 'bytes20')),
            'balance': Wei(0),
            'happy': False,
            'revealed': False,
            'secret': HexString('0x0', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0', 'bytes32'),
        },
        'seller': {
            '_address': EthAddress(HexString('0x0', 'bytes20')),
            'balance': Wei(0),
            'happy': False,
            'revealed': False,
            'secret': HexString('0x0', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0', 'bytes32'),
        },
    }

    _start_value = 10

    testing_variables = {
        'offer': _start_value / 2,
        'deposit': _start_value / 2,
        'deployer': _deployer,
        'bond': _bond,
        'buyer': _buyer,
        'seller': _seller,
        # This is just "any bytes32". Hardcoded for now.
        'sale_hash': (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                      b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                      b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r'),
        # This gets incrementally updated and confirmed _by each state fixture_.
        # If a fixture is not used this does not get checked! Tests can update
        # the expected `Sale` incrementally as needed for more sophistocated tests.
        'expected_sale': _expected_sale,
        'buyer_signal': _buyer_signal,
        'seller_signal': _seller_signal,
    }
    globals().update(testing_variables)

def get_sale_dict(sale):
    offer, state, b, s = sale.return_value
    participant_fields = (
        '_address', 'revealed', 'signal',
        'happy', 'signal_hash', 'secret', 'balance')
    return {
        'offer': offer,
        'state': state,
        'buyer': dict(zip(participant_fields, b)),
        'seller': dict(zip(participant_fields, s)),
    }

@pytest.fixture
def deployed(params):
    globals().update({'sale': deployer.deploy(SignalSale)})
    # FIXME: At this point LHS state=None and RHS state=0, but this passes.
    # The following line SHOULD be required!
    expected_sale['state'] = NOT_STARTED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def started(deployed):
    sale.start(sale_hash, seller, {'from': buyer, 'value': offer + deposit + bond})
    expected_sale['offer'] = offer
    expected_sale['buyer']['_address'] = buyer.address
    expected_sale['buyer']['happy'] = True
    expected_sale['seller']['_address'] = seller.address
    expected_sale['seller']['happy'] = True
    expected_sale['state'] = STARTED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def accepted(started):
    sale.accept(sale_hash, {'from': seller, 'value': deposit + bond})
    expected_sale['state'] = ACCEPTED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def canceled(started):
    sale.cancel(sale_hash, {'from': buyer})
    expected_sale['buyer']['balance'] = offer + deposit;
    expected_sale['state'] = CANCELED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def finalized(accepted):
    sale.finalize(sale_hash, buyer_signal.signal_hash, {'from': buyer})
    expected_sale['buyer']['signal_hash'] = HexString(buyer_signal.signal_hash.hex(), 'bytes32')
    expected_sale['state'] = FINALIZED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def signaled(finalized):
    sale.sellerSignals(sale_hash, seller_signal.signal_hash, {'from': seller})
    expected_sale['seller']['signal_hash'] = HexString(seller_signal.signal_hash.hex(), 'bytes32')
    expected_sale['state'] = SIGNALED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def revealed(signaled):
    sale.reveal(sale_hash, seller_signal.secret, seller_signal.signal, seller_signal.happy, {'from': seller})
    expected_sale['seller']['revealed'] = True
    expected_sale['seller']['signal'] = seller_signal.signal
    expected_sale['seller']['happy'] = seller_signal.happy
    expected_sale['seller']['balance'] -= seller_signal.signal
    expected_sale['buyer']['balance'] += deposit # buyer's deposit
    expected_sale['buyer']['balance'] += seller_signal.signal if seller_signal.happy else 0
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

    sale.reveal(sale_hash, buyer_signal.secret, buyer_signal.signal, buyer_signal.happy, {'from': buyer})
    expected_sale['buyer']['revealed'] = True
    expected_sale['buyer']['signal'] = buyer_signal.signal
    expected_sale['buyer']['happy'] = buyer_signal.happy
    expected_sale['buyer']['balance'] -= buyer_signal.signal
    expected_sale['seller']['balance'] += offer + deposit # seller's deposit
    expected_sale['seller']['balance'] += buyer_signal.signal if buyer_signal.happy else 0
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)


@pytest.fixture
def withdrawn(revealed):
    sale.withdraw(sale_hash, {'from': seller})
    expected_sale['seller']['balance'] = 0
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

    sale.withdraw(sale_hash, {'from': buyer})
    expected_sale['buyer']['balance'] = 0
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

@pytest.fixture
def bond_withdrawn(withdrawn):
    sale.withdrawBond({'from': seller})
    assert(sale._bond(seller).return_value == LAPSED)
    sale.withdrawBond({'from': buyer})
    assert(sale._bond(buyer).return_value == LAPSED)


# These just exist to force the above fixtures to run. Any fixtures that are
# used elsewhere can be removed from the below wrappers.
def test_deployed_fixture(deployed): pass
def test_started_fixture(started): pass
def test_canceled_fixture(canceled): pass
def test_accepted_fixture(accepted): pass
def test_finalized_fixture(finalized): pass
def test_signaled_fixture(signaled): pass
def test_revealed_fixture(revealed): pass
def test_withdrawn_fixture(withdrawn): pass
def test_bond_withdrawn_fixture(bond_withdrawn): pass

def test_canceled_withdrawl(started):
    with reverts():
        sale.cancel(sale_hash, {'from': seller})
    sale.cancel(sale_hash, {'from': buyer})
    expected_sale['buyer']['balance'] = offer + deposit;
    expected_sale['state'] = CANCELED
    assert(get_sale_dict(sale._sale(sale_hash)) == expected_sale)

def test_start_same_sale_hash(started):
    with reverts():
        sale.start(sale_hash, seller, {'from': buyer, 'value': offer + deposit + bond})

def test_deposit_and_offer_odd(deployed):
    with reverts():
        sale.start(sale_hash, seller, {'from': buyer, 'value': (offer + deposit + 1) + bond})

def test_start_lapsed_bond(bond_withdrawn):
    # Buyer starts sale successfully (and is bonded).
    # Buyer withdrawls bond.
    # Buyer tries to start a _2nd_ sale after withdrawing (and therefore LAPSED).
    new_sale_hash = HexString('0x1234beefc0ff1e', 'bytes32')
    with reverts():
        sale.start(new_sale_hash, seller, {'from': buyer, 'value': offer + deposit + bond})
