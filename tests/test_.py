#!/usr/bin/env python3

import pytest
import brownie
from brownie import Sale, accounts
from brownie.test import strategy

# State enum values. These need to account for any solidity changes.
DEPLOYED = 0
STARTED = 1
ACCEPTED = 2
FINALIZED = 3

def fhex(n):
    return '0x' + n.hex()

@pytest.fixture
def params():
    # MAGIC HACK: these are "injected" via a globals update.
    testing_variables = {
        'deployer': accounts[0],
        'buyer': accounts[1],
        'seller': accounts[2],
        # This is just "any bytes32". Hardcoded for now.
        'sale_hash': (b'f\xd0Y\xea\x1e\x9b5\x10\xfcV\xa0'
                      b'\xba\xa4\x15\xd7\x0e\r\xb0g\xde'
                      b'\x13%\x84v\xfe\xe6(\xa5\xf9\x94\xd5\r'),
    }
    globals().update(testing_variables)

@pytest.fixture
def deployed(params):
    testing_variables = {'sale_contract': accounts[0].deploy(Sale)}
    globals().update(testing_variables)

@pytest.fixture
def started(params):
    testing_variables = {'sale_contract': accounts[0].deploy(Sale)}
    globals().update(testing_variables)
    sale_contract.startSale(sale_hash, seller, {'from': buyer})

@pytest.fixture
def accepted(params):
    testing_variables = {'sale_contract': accounts[0].deploy(Sale)}
    globals().update(testing_variables)
    sale_contract.startSale(sale_hash, seller, {'from': buyer})
    sale_contract.acceptCurrentOffer({'from': seller})

def test_constructor(deployed):
    assert sale_contract.buyer_happy() == True
    assert sale_contract.seller_happy() == True
    assert sale_contract.state() == DEPLOYED

def test_blind_call_to_accept(deployed):
    assert sale_contract.state() == DEPLOYED
    for wallet in [deployer, seller, buyer]:  # Try three wallets, because.
        # This should revert because
        #   1. state!=STARTED
        #   2. seller_address is uninitialized
        with brownie.reverts():
            sale_contract.acceptCurrentOffer({'from': wallet})

def test_started_state(started):
    assert sale_contract.sale_hash() == fhex(sale_hash)
    assert sale_contract.seller_address() == seller.address
    assert sale_contract.buyer_address() == buyer.address
    assert sale_contract.state() == STARTED

def test_accept(started):
    # This should revert. We are in the right `state` but the buyer
    # should not be able to accept.
    with brownie.reverts():
        sale_contract.acceptCurrentOffer({'from': buyer})
    sale_contract.acceptCurrentOffer({'from': seller})
    assert sale_contract.state() == ACCEPTED
    # The state is now ACCEPTED: no one, including the seller should be able
    # to reject.
    with brownie.reverts():
        sale_contract.reject(True, {'from': seller})

def test_reject(started):
    # The seller rejects this STARTED sale with happy=False
    sale_contract.reject(False, {'from': seller})
    assert sale_contract.seller_happy() == False
    assert sale_contract.buyer_happy() == True

def test_finalize(accepted):
    sale_contract.finalize(False, {'from': buyer})
    assert sale_contract.seller_happy() == True
    assert sale_contract.buyer_happy() == False
