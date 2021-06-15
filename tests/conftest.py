#!/usr/bin/python3

import pytest
from namehash import namehash


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass


@pytest.fixture(scope="module", autouse=True)
def ens(ENSRegistry, accounts, web3):
    ens = ENSRegistry.deploy({'from': accounts[0]})
    return ens


@pytest.fixture(scope="module", autouse=True)
def baseRegistrar(BaseRegistrarImplementation, ens, accounts, web3):
    baseRegistrar = BaseRegistrarImplementation.deploy(
        ens.address, namehash('eth'), {'from': accounts[0]})

    baseRegistrar.addController(accounts[1], {'from': accounts[0]})
    ens.setSubnodeOwner('0x0', web3.sha3(text='eth'),
                        baseRegistrar.address, {'from': accounts[0]})
    return baseRegistrar

@pytest.fixture(scope="module", autouse=True)
def stablePriceOracle(DummyOracle,StablePriceOracle,baseRegistrar, ens, accounts, web3):
    # Dummy oracle with 1 ETH == 10 USD
    dummyOracle =  DummyOracle.deploy(1000000000, {'from': accounts[0]});
    # 4 attousd per second for 3 character names, 2 attousd per second for 4 character names,
    # 1 attousd per second for longer names.
    priceOracle =  StablePriceOracle.deploy(dummyOracle.address, [0, 0, 4, 2, 1], {'from': accounts[0]});
    return priceOracle
