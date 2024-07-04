// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CarbonBase is Ownable {
    address[] public managers;
    mapping(address => bool) public isManager;
    Token[] public tokens;
    //代币地址->铸币权限者
    mapping(address => address[]) public coinageAddrs;
    //管理员地址->新管理员地址->投票
    mapping(address => mapping(address => Vote)) public managerVotes;
    //管理员地址->token地址->投票
    mapping(address => mapping(address => Vote)) public tokenVotes;
    //token地址->管理员地址->铸币人地址->投票
    mapping(address => mapping(address => mapping(address => Vote))) public coinageVotes;

    enum Vote {
        DEFAULT, ADD_MANAGER, REMOVE_MANAGER, ADD_TOKEN, UPDATE_TOKEN, ADD_COINAGE_ADDR, REMOVE_COINAGE_ADDR
    }

    struct Token {
        address tokenAddress;
        bytes32 name;
        uint tokenType;
    }

    modifier onlyManager() {
        require(isManager[msg.sender], "Not manager");
        _;
    }

    constructor() Ownable(msg.sender){
    }

    function InitManager(address[] memory addrs) public onlyOwner returns (bool) {
        require(managers.length == 0, "Managers already initialized");
        for (uint i = 0; i < addrs.length; i++) {
            managers.push(addrs[i]);
            isManager[addrs[i]] = true;
        }
        return true;
    }

    function AddManager(address addrs) public onlyManager returns (bool) {
        require(!isManager[addrs], "Already a manager");
        bool add = checkManagerVotes(addrs, Vote.ADD_MANAGER);
        if (!add) {
            return false;
        }
        managers.push(addrs);
        isManager[addrs] = true;
        return true;
    }

    function RemoveManager(address addrs) public onlyManager returns (bool) {
        require(isManager[addrs], "Not a manager");
        bool remove = checkManagerVotes(addrs, Vote.REMOVE_MANAGER);
        if (!remove) {
            return false;
        }
        for (uint i = 0; i < managers.length; i++) {
            if (managers[i] == addrs) {
                managers[i] = managers[managers.length - 1];
                managers.pop();
                isManager[addrs] = false;
                return true;
            }
        }
        return false;
    }

    function ShowManager() public view returns (address[] memory) {
        return managers;
    }

    function AddToken(address addrs, bytes32 name, uint tokenType) public onlyManager returns (bool) {
        //todo检查已经添加token
        bool add = checkManagerVotes(addrs, Vote.ADD_TOKEN);
        if (!add) {
            return false;
        }
        Token memory newToken = Token({
            tokenAddress: addrs,
            name: name,
            tokenType: tokenType
        });
        tokens.push(newToken);
        return true;
    }

    function UpdateToken(address addrs, bytes32 name, uint tokenType) public onlyManager returns (bool) {
        uint index = 0;
        for (; index < tokens.length; index++) {
            if (tokens[index].tokenType == tokenType) {
                break;
            }
        }
        require(index < tokens.length, "token type not exist");
        bool update = checkManagerVotes(addrs, Vote.UPDATE_TOKEN);
        if (!update) {
            return false;
        }
        Token storage token = tokens[index];
        token.name = name;
        token.tokenAddress = addrs;
        token.tokenType = tokenType;
        return true;
    }

    function ShowToken() public view returns (bool, address[] memory, bytes32[] memory, uint[] memory) {
        address[] memory tokenAddresses = new address[](tokens.length);
        bytes32[] memory tokenNames = new bytes32[](tokens.length);
        uint[] memory tokenTypes = new uint[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            tokenAddresses[i] = tokens[i].tokenAddress;
            tokenNames[i] = tokens[i].name;
            tokenTypes[i] = tokens[i].tokenType;
        }
        return (true, tokenAddresses, tokenNames, tokenTypes);
    }

    function validCoinageAddress(address tokenAddress, address sender) public view returns (bool) {
        for (uint i = 0; i < coinageAddrs[tokenAddress].length; i++) {
            if (coinageAddrs[tokenAddress][i] == sender) {
                return true;
            }
        }
        return false;
    }

    function SetCoinage(address addrs, address subcontractaddr) public onlyManager returns (bool) {
        bool add = checkManagerVotesForCoinage(addrs, subcontractaddr, Vote.ADD_COINAGE_ADDR);
        if (!add) {
            return false;
        }
        coinageAddrs[subcontractaddr].push(addrs);
        return true;
    }

    function RemoveCoinage(address addrs, address subcontractaddr) public onlyManager returns (bool) {
        uint index = 0;
        address[] storage addrsForCoinage = coinageAddrs[subcontractaddr];
        for (; index < addrsForCoinage.length; index++) {
            if (addrsForCoinage[index] == subcontractaddr) {
                break;
            }
        }
        require(index < tokens.length, "addrs not in coinage addresses");
        bool remove = checkManagerVotesForCoinage(addrs, subcontractaddr, Vote.REMOVE_COINAGE_ADDR);
        if (!remove) {
            return false;
        }
        addrsForCoinage[index] = addrsForCoinage[addrsForCoinage.length - 1];
        addrsForCoinage.pop();
        return true;
    }

    function ShowCoinage() public view returns (bool, address[][] memory, uint[] memory) {
        address[][] memory coinageAddress = new address[][](0);
        uint[] memory tokenTypes = new uint[](tokens.length);

        for (uint i = 0; i < tokens.length; i++) {
            coinageAddress[i] = coinageAddrs[tokens[i].tokenAddress];
            tokenTypes[i] = tokens[i].tokenType;
        }
        return (true, coinageAddress, tokenTypes);
    }

    function checkManagerVotes(address addrs, Vote vote) internal returns (bool) {
        mapping(address => mapping(address => Vote)) storage voteMap = managerVotes;
        if (vote == Vote.ADD_MANAGER || vote == Vote.REMOVE_MANAGER) {
            voteMap = managerVotes;
        } else if (vote == Vote.ADD_TOKEN || vote == Vote.UPDATE_TOKEN) {
            voteMap = tokenVotes;
        }
        //本人投票
        voteMap[msg.sender][addrs] = vote;

        //检查全部投票是否完成
        bool voteSuccess = true;
        //使用for index循环的情况下，如果当前addr的投票结束前，又增加了一个manager，新的manager也可以参与投票
        for (uint i = 0; i < managers.length; i++) {
            if (voteMap[managers[i]][addrs] != vote) {
                voteSuccess = false;
                break;
            }
        }
        return voteSuccess;
    }

    function checkManagerVotesForCoinage(address coinageAddress, address subContractAddr, Vote vote) internal view returns (bool) {
        //检查全部投票是否完成
        bool voteSuccess = true;
        //使用for index循环的情况下，如果当前addr的投票结束前，又增加了一个manager，新的manager也可以参与投票
        for (uint i = 0; i < managers.length; i++) {
            if (coinageVotes[managers[i]][subContractAddr][coinageAddress] != vote) {
                voteSuccess = false;
                break;
            }
        }
        return voteSuccess;
    }

}
