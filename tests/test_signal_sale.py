#!/usr/bin/env python3

import itertools
import pytest
from brownie import SignalSale, accounts, reverts
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
        'deployer': accounts[0],
        'buyer': accounts[1],
        'seller': accounts[1],
        # This is just "any bytes32". Hardcoded for now.
        'sale_hash': (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                      b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                      b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r'),
        # This gets incrementally updated and confirmed _by each state fixture_.
        # If a fixture is not used this does not get checked! Tests can update
        # the expected `Sale` incrementally as needed for more sophistocated tests.
        'expected_sale': _expected_sale,
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
    # The following line should be required!
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
    # test this fixture's correctness
    assert(get_sale_dict(sale_contract.sales(sale_hash)) == expected_sale)

@pytest.fixture
def canceled(started):
    sale_contract.cancel(sale_hash, {'from': buyer})
    expected_sale['buyer']['balance'] = start_value;
    expected_sale['state'] = CANCELED
    # test this fixture's correctness
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
