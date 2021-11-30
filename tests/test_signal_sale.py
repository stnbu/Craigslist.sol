#!/usr/bin/env python3

import itertools
import pytest
from brownie import SignalSale, accounts, reverts

# State enum values. These need to account for any solidity changes.
DEPLOYED = 0
STARTED = 1
ACCEPTED = 2
FINALIZED = 3

def fhex(n):
    return '0x' + n.hex()

@pytest.fixture
def params():
    send_to_start = 10  # yes, ten Wei. Is there an argument to use "realistic
                        # amounts of money"?
    # NOTE MAGIC HACK: these are "injected" via a globals update.
    testing_variables = {
        'deployer': accounts[0],
        'buyer': accounts[1],
        'seller': accounts[2],
        # This is just "any bytes32". Hardcoded for now.
        'sale_hash': (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                      b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                      b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r'),
        'initial_send': send_to_start,
        'initial_offer': send_to_start / 2,
        'initial_deposit': send_to_start / 2,
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

def test_constructor(deployed):
    assert sale_contract.seller_address() == '0x' + '0' * 40
    assert sale_contract.buyer_address() == '0x' + '0' * 40
    assert sale_contract.state() == DEPLOYED
    assert sale_contract.offer() == 0;
    assert sale_contract.buyer_deposit() == 0;
    assert sale_contract.seller_deposit() == 0;
    assert_balance_math_pre_finalize(sale_contract)

def test_start_deposit_too_small(deployed):
    with reverts():
        sale_contract.start(sale_hash, seller, initial_deposit - 1, {'from': buyer, 'value': initial_send})
    assert_balance_math_pre_finalize(sale_contract)

def test_blind_call_to_accept(deployed):
    # This should revert because
    #   1. state!=STARTED
    #   2. seller_address is uninitialized
    with reverts():
        sale_contract.accept({'from': seller, 'value': initial_offer})
    assert_balance_math_pre_finalize(sale_contract)

def test_reject_deployed(deployed):
    combos = itertools.product(
        [0, 1],
        [True, False],
        [seller, buyer],
    )
    for signal, happy, caller in combos:
        with reverts():
            sale_contract.reject(signal, happy, {'from': caller})
    assert_balance_math_pre_finalize(sale_contract)


def test_state_started(started):
    assert sale_contract.sale_hash() == fhex(sale_hash)
    assert sale_contract.seller_address() == seller.address
    assert sale_contract.buyer_address() == buyer.address
    assert sale_contract.state() == STARTED
    assert sale_contract.offer() == initial_offer
    assert sale_contract.seller_deposit() == 0
    assert sale_contract.buyer_deposit() == initial_deposit
    assert_balance_math_pre_finalize(sale_contract)

def test_accept_deposit_too_small(started):
    with reverts():
        sale_contract.accept({'from': seller, 'value': initial_offer - 1})
    assert_balance_math_pre_finalize(sale_contract)

def test_state_accepted(accepted):
    assert sale_contract.sale_hash() == fhex(sale_hash)
    assert sale_contract.seller_address() == seller.address
    assert sale_contract.buyer_address() == buyer.address
    assert sale_contract.state() == ACCEPTED
    assert sale_contract.offer() == initial_offer
    assert sale_contract.seller_deposit() == initial_deposit
    assert sale_contract.buyer_deposit() == initial_deposit
    assert_balance_math_pre_finalize(sale_contract)

def test_reject_after_accepted(accepted):
    combos = itertools.product(
        [0, 1],
        [True, False],
        [seller, buyer],
    )
    for signal, happy, caller in combos:
        with reverts():
            sale_contract.reject(signal, happy, {'from': caller})
    assert_balance_math_pre_finalize(sale_contract)

def test_state_finalized(finalized):
    assert sale_contract.sale_hash() == fhex(sale_hash)
    assert sale_contract.seller_address() == seller.address
    assert sale_contract.buyer_address() == buyer.address
    assert sale_contract.state() == FINALIZED
    assert sale_contract.offer() == initial_offer
    # These public variables retain their last set value.
    # They do not reflect any fund transfers.
    assert sale_contract.seller_deposit() == initial_deposit
    assert sale_contract.buyer_deposit() == initial_deposit
    with pytest.raises(AssertionError): # because we do not update on finalize
        assert_balance_math_pre_finalize(sale_contract)
