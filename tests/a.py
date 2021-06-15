from namehash import namehash, sha3

from web3 import Web3

eth_node = namehash('eth')
foo_eth_node = namehash('foo.eth')
print(eth_node)
print(foo_eth_node)

eth = Web3.sha3(text='eth').hex()
print(eth)


# b=Web3.soliditySha3(['uint256','uint256'], [eth_node,a])
# print(b.hex())
# bytes32 subnode = keccak256(abi.encodePacked(node, label))
