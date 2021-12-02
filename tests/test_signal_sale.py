#!/usr/bin/env python3

import itertools
import pytest
from brownie import SignalSale, accounts, reverts

from brownie.convert.datatypes import HexString, EthAddress, Wei

# State enum values. These need to account for any solidity changes.
DEPLOYED = 0
STARTED = 1
ACCEPTED = 2
FINALIZED = 3

def fhex(n):
    return '0x' + n.hex()

@pytest.fixture
def params():
    send_to_start = 10
    # This is just "any bytes32". Hardcoded for now.
    _sale_hash = (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                  b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                  b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r')
    deployer = accounts[0]
    seller = accounts[1]
    buyer = accounts[2]

    _default_expected_sale = {
        'offer': Wei(send_to_start / 2),
        'state': None,
        'buyer': {
            '_address': buyer,
            'balance': Wei(0),
            'happy': True,
            'revealed': False,
            'salt': HexString('0x0000000000000000000000000000000000000000000000000000000000000000', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0000000000000000000000000000000000000000000000000000000000000000', 'bytes32'),
        },
        'seller': {
            '_address': seller,
            'balance': Wei(0),
            'happy': True,
            'revealed': False,
            'salt': HexString('0x0000000000000000000000000000000000000000000000000000000000000000', 'bytes32'),
            'signal': Wei(0),
            'signal_hash': HexString('0x0000000000000000000000000000000000000000000000000000000000000000', 'bytes32'),
        },
    }

    testing_variables = {
        'deployer': deployer,
        'buyer': buyer,
        'seller': seller,
        'initial_send': send_to_start,
        'initial_offer': send_to_start / 2,
        'initial_deposit': send_to_start / 2,
        'sale_hash': _sale_hash,
        'default_expected_sale': _default_expected_sale,
    }
    globals().update(testing_variables)

def assert_balance_math_pre_finalize(contract):
    assert (contract.offer() +
            contract.seller_deposit() +
            contract.buyer_deposit()
            ==
            contract.balance())

@pytest.fixture
def deployed(params):
    # We get a new contract instance for each test using this harness. Same below.
    testing_variables = {'sale_contract': deployer.deploy(SignalSale)}
    globals().update(testing_variables)

@pytest.fixture
def started(params):
    testing_variables = {'sale_contract': deployer.deploy(SignalSale)}
    globals().update(testing_variables)
    sale_contract.start(sale_hash, seller, initial_deposit, {'from': buyer, 'value': initial_send})

@pytest.fixture
def accepted(params):
    testing_variables = {'sale_contract': deployer.deploy(SignalSale)}
    globals().update(testing_variables)
    sale_contract.start(sale_hash, seller, initial_deposit, {'from': buyer, 'value': initial_send})
    sale_contract.accept({'from': seller, 'value': initial_deposit})

@pytest.fixture
def finalized(params):
    testing_variables = {'sale_contract': deployer.deploy(SignalSale)}
    globals().update(testing_variables)
    sale_contract.start(sale_hash, seller, initial_deposit, {'from': buyer, 'value': initial_send})
    sale_contract.accept({'from': seller, 'value': initial_deposit})
    sale_contract.finalize(0, True, {'from': buyer})

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

def test_constructor(deployed):
    sale_contract.start(sale_hash, seller, {'from': buyer, 'value': initial_send})
    sale = get_sale_dict(sale_contract.sales(sale_hash))
    default_expected_sale['state'] = STARTED
    assert(sale == default_expected_sale)
