// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Mock GuideDAO Token contract for local testing.
 *
 * The intended use is following:
 * Deploy this contract => Become an owner => Grant admin permissions
 * to lottery contract with setAdmin() => call mintTo() after winner reveal.
 */
contract GuideDAOTokenMock is IERC721Metadata, Pausable {
    string private constant BASE_URI = "ipfs://";
    string private constant _name = "GuideDAO Access Token";
    string private constant _symbol = "GDAT";

    address private immutable _owner;

    mapping(address => uint256) private _ids;
    mapping(uint256 => address) private _owners;

    uint256 public currentIdToMint = 1;
    uint256 public MAX_GRADE = 2;
    mapping(address => bool) public admins;
    mapping(address => bool) public whiteList;

    error TokenDoesNotExist(uint256 tokenId);
    error NotAnAdminOrOwner(address sender);
    error NotAnOwner(address sender);
    error AddressAlreadyHasToken(address recipient);
    error OwnerIsZero();
    error BurnNotTransfer();
    error SendingToContract(address recipient);
    error NotTokenOwner(address from, uint256 tokenId);
    error AlreadyTokenOwner(address to, uint256 tokenId);
    error NotInWhiteList(address student);

    modifier isMinted(uint256 tokenId) {
        if (_owners[tokenId] == address(0)) {
            revert TokenDoesNotExist(tokenId);
        }
        _;
    }

    modifier isAdmin() {
        if (!admins[msg.sender] && msg.sender != _owner) {
            revert NotAnAdminOrOwner(msg.sender);
        }
        _;
    }

    modifier isFirstToken(address to) {
        if (balanceOf(to) != 0) {
            revert AddressAlreadyHasToken(to);
        }
        _;
    }

    modifier isOwner() {
        if (msg.sender != _owner) {
            revert NotAnOwner(msg.sender);
        }
        _;
    }

    constructor() payable {
        _owner = msg.sender;
    }

    function setIsAdmin(
        address admin,
        bool _isAdmin
    ) external whenNotPaused isAdmin {
        admins[admin] = _isAdmin;
    }

    function setIsInWhiteList(
        address student,
        bool isInWhiteList
    ) public whenNotPaused isAdmin isFirstToken(student) {
        whiteList[student] = isInWhiteList;
    }

    function mint() public whenNotPaused {
        if (!whiteList[msg.sender]) {
            revert NotInWhiteList(msg.sender);
        }
        whiteList[msg.sender] = false;
        _mintTo(msg.sender);
    }

    function mintTo(address to) public whenNotPaused isAdmin {
        _mintTo(to);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused isAdmin {
        _safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused isAdmin isFirstToken(to) {
        _transferFrom(from, to, tokenId);
    }

    function balanceOf(
        address owner
    ) public view override returns (uint256 balance) {
        if (owner == address(0)) {
            revert OwnerIsZero();
        }
        return _ids[owner] == 0 ? 0 : 1;
    }

    function ownerOf(
        uint256 tokenId
    ) public view override isMinted(tokenId) returns (address owner) {
        return _owners[tokenId];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override {}

    function pause() external isOwner {
        _pause();
    }

    function unpause() external isOwner {
        _unpause();
    }

    function approve(address to, uint256 tokenId) external override {}

    function setApprovalForAll(
        address operator,
        bool _approved
    ) external override {}

    function name() external pure override returns (string memory) {
        return _name;
    }

    function symbol() external pure override returns (string memory) {
        return _symbol;
    }

    function tokenURI(
        uint256 tokenId
    ) external view override isMinted(tokenId) returns (string memory) {
        return "tokenURI";
    }

    function getApproved(
        uint256 tokenId
    ) external pure override returns (address operator) {}

    function isApprovedForAll(
        address owner,
        address operator
    ) external pure override returns (bool) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) private {
        if (to == address(0)) {
            revert BurnNotTransfer();
        }
        if (to.code.length != 0) {
            revert SendingToContract(to);
        }
        _transferFrom(from, to, tokenId);
    }

    function _transferFrom(address from, address to, uint256 tokenId) private {
        if (_owners[tokenId] != from) {
            revert NotTokenOwner(from, tokenId);
        }

        if (_owners[tokenId] == to) {
            revert AlreadyTokenOwner(to, tokenId);
        }

        //если это не mint
        if (from != address(0)) {
            delete _ids[from];
        }

        //если это не burn
        if (to != address(0)) {
            _ids[to] = tokenId;
        }
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _mintTo(address to) private isFirstToken(to) {
        _safeTransferFrom(address(0), to, currentIdToMint);
        ++currentIdToMint;
    }
}
