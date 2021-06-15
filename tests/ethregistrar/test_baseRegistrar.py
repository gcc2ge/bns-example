#!/usr/bin/python3
import pytest
import brownie
from namehash import namehash


@pytest.mark.skip
def test_registar(ens, baseRegistrar, accounts, web3, chain):
    registrantAccount = accounts[2]
    controllerAccount = accounts[1]

    baseRegistrar.register(web3.sha3(text="newname"),
                           registrantAccount, 86400, {'from': controllerAccount})
    assert ens.owner(namehash("newname.eth")) == registrantAccount

    assert baseRegistrar.ownerOf(
        web3.sha3(text="newname")) == registrantAccount

    nameExpires = baseRegistrar.nameExpires(web3.sha3(text="newname"))
    assert nameExpires == chain.time() + 86400


@pytest.mark.skip
def test_registar_renew(ens, baseRegistrar, accounts, web3, chain):
    registrantAccount = accounts[2]
    controllerAccount = accounts[1]

    baseRegistrar.register(web3.sha3(text="newname"),
                           registrantAccount, 86400, {'from': controllerAccount})

    oldExpires = baseRegistrar.nameExpires(web3.sha3(text="newname"))
    baseRegistrar.renew(web3.sha3(text="newname"), 86400,
                        {'from': controllerAccount})
    nameExpires = baseRegistrar.nameExpires(web3.sha3(text="newname"))
    assert nameExpires == oldExpires+86400


@pytest.mark.skip
def test_registar_reclaim(ens, baseRegistrar, accounts, web3, chain):
    ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
    ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000"

    controllerAccount = accounts[1]
    registrantAccount = accounts[2]

    ens.setSubnodeOwner(ZERO_HASH, web3.sha3(text="eth"),
                        accounts[0], {'from': accounts[0]})
    ens.setSubnodeOwner(namehash("eth"), web3.sha3(
        text="newname"), ZERO_ADDRESS, {'from': accounts[0]})
    assert ens.owner(namehash("newname.eth")) == ZERO_ADDRESS

    # 将 0x0.eth 设置给 registar
    ens.setSubnodeOwner(ZERO_HASH, web3.sha3(
        text="eth"), baseRegistrar.address, {'from': accounts[0]})

    baseRegistrar.addController(controllerAccount, {'from': accounts[0]})
    baseRegistrar.register(web3.sha3(text="newname"),
                           registrantAccount, 86400, {'from': controllerAccount})

    assert ens.owner(namehash("newname.eth")) == registrantAccount

    # registrantAccount 将 newname.eth的owner分配给 accounts[4]
    baseRegistrar.reclaim(web3.sha3(text="newname"), accounts[4], {
                          'from': registrantAccount})

    assert ens.owner(namehash("newname.eth")) == accounts[4]


@pytest.mark.skip
def test_registar_transferOwner(ens, baseRegistrar, accounts, web3, chain):
    registrantAccount = accounts[2]
    controllerAccount = accounts[1]
    otherAccount = accounts[4]

    baseRegistrar.register(web3.sha3(text="newname"),
                           registrantAccount, 86400, {'from': controllerAccount})
    assert ens.owner(namehash("newname.eth")) == registrantAccount

    # NFT transfer
    baseRegistrar.transferFrom(registrantAccount, otherAccount, web3.sha3(
        text="newname"), {'from': registrantAccount})

    assert baseRegistrar.ownerOf(web3.sha3(text="newname")) == otherAccount

    # Transfer does not update ENS without a call to reclaim.
    assert ens.owner(namehash("newname.eth")) == registrantAccount
    baseRegistrar.reclaim(web3.sha3(text="newname"), otherAccount, {
                          'from': otherAccount})
    assert ens.owner(namehash("newname.eth")) == otherAccount


@pytest.mark.skip
def test_registar_expire(ens, baseRegistrar, accounts, web3, chain):
    registrantAccount = accounts[2]
    controllerAccount = accounts[1]
    otherAccount = accounts[4]

    baseRegistrar.register(web3.sha3(text="newname"),
                           registrantAccount, 86400, {'from': controllerAccount})

    ts = chain.time()
    nameExpires = baseRegistrar.nameExpires(web3.sha3(text="newname"))
    grace = baseRegistrar.GRACE_PERIOD()  # 过期后 保留 90 天
    # block.timestamp => chain.mine
    chain.mine(nameExpires - ts + grace + 36000)

    with brownie.reverts():
        baseRegistrar.ownerOf(web3.sha3(text="newname"))

    baseRegistrar.register(web3.sha3(text="newname"), otherAccount, 86400, {
                           'from': controllerAccount})
    assert baseRegistrar.ownerOf(namehash("newname")) == otherAccount

# @pytest.mark.skip
def test_registar_resolver(ens, baseRegistrar, accounts, web3, chain):
    ownerAccount = accounts[0]
    baseRegistrar.setResolver(accounts[1], {'from': ownerAccount})

    assert ens.resolver(namehash('eth')) == accounts[1]
