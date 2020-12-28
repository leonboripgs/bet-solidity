pragma solidity ^0.5.4;


/**
 * Randomizer to generating psuedo random numbers for JUST.BET
 */
contract Randomizer {
    function getRandom(uint256 gamerange) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp +
                            block.difficulty +
                            uint256(keccak256(abi.encodePacked(block.coinbase)))
                    )
                )
            ) % gamerange;
    }

    function getRandom(uint256 gamerange, uint256 seed)
    internal
        view
        returns (uint256)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        now +
                            block.difficulty +
                            uint256(
                                keccak256(abi.encodePacked(block.coinbase))
                            ) +
                            seed
                    )
                )
            ) % gamerange;
    }

    function getRandom() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp +
                            block.difficulty +
                            uint256(keccak256(abi.encodePacked(block.coinbase)))
                    )
                )
            );
    }
}
