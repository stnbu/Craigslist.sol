#!/usr/bin/env python3

import pytest
import web3
from brownie import accounts, SignalSale, SolidityHelpers
from brownie.convert.datatypes import HexString, EthAddress, Wei

# State enum values. These need to account for any solidity changes.
NOT_STARTED = 0
STARTED = 1
ACCEPTED = 2
FINALIZED = 3
SIGNALED = 4
CANCELED = 5

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
                self.salt,
                self.signal,
                self.happy,
                {'from': account})
            self.signal_hash = tx.return_value

    _deployer = accounts[0]
    _buyer = accounts[1]
    _seller = accounts[2]

    _buyer_signal = ParticipantSignal({
        'salt': HexString('0xb10beef', 'bytes32'),
        'signal': Wei(1),
        'happy': True
    }, _buyer)

    _seller_signal = ParticipantSignal({
        'salt': HexString('0xbadbeef', 'bytes32'),
        'signal': Wei(1),
        'happy': False
    }, _seller)

    _expected_sale = {
        'offer': Wei(0),
        'state': None,
        'buyer': {
            '_address': EthAddress(HexString('0x0', 'bytes20')),
            'balance': Wei(0),
            'happy': False,
            'revealed': False,
            'salt': HexString('0x0', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0', 'bytes32'),
        },
        'seller': {
            '_address': EthAddress(HexString('0x0', 'bytes20')),
            'balance': Wei(0),
            'happy': False,
            'revealed': False,
            'salt': HexString('0x0', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0', 'bytes32'),
        },
    }

    testing_variables = {
        'start_value': 10,
        'deployer': _deployer,
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
    offer, state, b, s = sale
    participant_fields = (
        '_address', 'revealed', 'signal',
        'happy', 'signal_hash', 'salt', 'balance')
    return {
        'offer': offer,
        'state': state,
        'buyer': dict(zip(participant_fields, b)),
        'seller': dict(zip(participant_fields, s)),
    }

@pytest.fixture
def deployed(params):
    globals().update({'sale_contract': deployer.deploy(SignalSale)})
    # FIXME: At this point LHS state=None and RHS state=0, but this passes.
    # The following line SHOULD be required!
    #expected_sale['state'] = NOT_STARTED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def started(deployed):
    sale_contract.start(sale_hash, seller, {'from': buyer, 'value': start_value})
    expected_sale['buyer']['_address'] = buyer.address
    expected_sale['buyer']['happy'] = True
    expected_sale['seller']['_address'] = seller.address
    expected_sale['seller']['happy'] = True
    expected_sale['offer'] = start_value / 2
    expected_sale['state'] = STARTED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def accepted(started):
    sale_contract.accept(sale_hash, {'from': seller, 'value': start_value / 2})
    expected_sale['state'] = ACCEPTED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def canceled(started):
    sale_contract.cancel(sale_hash, {'from': buyer})
    expected_sale['buyer']['balance'] = start_value;
    expected_sale['state'] = CANCELED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def finalized(accepted):
    sale_contract.finalize(sale_hash, buyer_signal.signal_hash, {'from': buyer})
    expected_sale['buyer']['signal_hash'] = HexString(buyer_signal.signal_hash.hex(), 'bytes32')
    expected_sale['state'] = FINALIZED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def signaled(finalized):
    sale_contract.sellerSignals(sale_hash, seller_signal.signal_hash, {'from': seller})
    expected_sale['seller']['signal_hash'] = HexString(seller_signal.signal_hash.hex(), 'bytes32')
    expected_sale['state'] = SIGNALED
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def revealed(signaled):
    sale_contract.reveal(sale_hash, seller_signal.salt, seller_signal.signal, seller_signal.happy, {'from': seller})
    expected_sale['seller']['revealed'] = True
    expected_sale['seller']['signal'] = seller_signal.signal
    expected_sale['seller']['happy'] = seller_signal.happy
    expected_sale['seller']['balance'] = -1
    expected_sale['buyer']['balance'] = 2
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

    sale_contract.reveal(sale_hash, buyer_signal.salt, buyer_signal.signal, buyer_signal.happy, {'from': buyer})
    expected_sale['buyer']['revealed'] = True
    expected_sale['buyer']['signal'] = buyer_signal.signal
    expected_sale['buyer']['happy'] = buyer_signal.happy
    expected_sale['buyer']['balance'] = 1
    expected_sale['seller']['balance'] = 2
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)


@pytest.fixture
def xxx(revealed):
    sale_contract.withdraw(sale_hash, {'from': seller})
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)


# use the deployed fixture just once.
def test_deployed_fixture(deployed):
    pass

# use the started fixture just once.
def test_started_fixture(started):
    pass

# use the canceled fixture just once.
def test_canceled_fixture(canceled):
    pass

# use the accepted fixture just once.
def test_accepted_fixture(accepted):
    pass

# use the finalized fixture just once.
def test_finalized_fixture(finalized):
    pass

# use the signaled fixture just once.
def test_signaled_fixture(signaled):
    pass

# use the revealed fixture just once.
def test_revealed_fixture(revealed):
    pass

# use the withdrawn fixture just once.
def test_withdrawn_fixture(xxx):
    pass
