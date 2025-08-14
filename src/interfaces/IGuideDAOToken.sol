//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGuideDAOToken is IERC721 {
    function mintTo(address _to) external;
}
