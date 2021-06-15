#!/usr/bin/python3
import pytest
import brownie
from namehash import namehash


@pytest.mark.skip
def test_owner(ens, accounts, web3):
    result = ens.setSubnodeOwner('0x0', web3.sha3(
        text='eth'), accounts[3], {'from': accounts[0]})
    # print(result)
    eth_node = namehash('eth')
    ens_owner = ens.owner(eth_node.hex())
    assert ens_owner == accounts[3]


@pytest.mark.skip
def test_owner_subnode(ens, accounts, web3):
    result = ens.setSubnodeOwner('0x0', web3.sha3(
        text='eth'), accounts[3], {'from': accounts[0]})

    owner = ens.owner(result.return_value)
    assert owner == accounts[3]


@pytest.mark.skip
def test_hash(ens, accounts, web3):
    result = ens.setSubnodeOwner('0x0', web3.sha3(
        text='eth'), accounts[3], {'from': accounts[0]})

    eth_node = namehash('eth')
    assert eth_node.hex() == result.return_value
