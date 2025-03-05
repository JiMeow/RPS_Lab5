
// SPDX-License-Identifier: GPL-3.0

import "./CommitReveal.sol";
import "./TimeUnit.sol";

pragma solidity >=0.7.0 <0.9.0;

contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public numPlayerReveal = 0;
    uint public reward = 0;

    mapping(address => uint) private player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors , 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    mapping(address => bool) public player_not_revealed;

    address[] public players;

    uint public numInput = 0;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.sender == 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        require(msg.sender == 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        require(msg.sender == 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
        require(msg.sender == 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);

        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }

        require(msg.value == 1 ether);
        reward += msg.value;
        player_not_played[msg.sender] = true;
        player_not_revealed[msg.sender] = true;

        players.push(msg.sender);
        numPlayer++;

        setStartTime();
    }

    function hash(uint choice, bytes32 salt) public pure returns (bytes32) {
        require(choice >= 0 && choice <= 4);

        return getHash(keccak256(abi.encodePacked(choice, salt)));
    }

    function input(bytes32 hashedInput) public  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);

        commit(hashedInput);
        player_not_played[msg.sender] = false;

        numInput++;
    }

    function reveal(uint choice, bytes32 salt) public {
        require(numInput == 2);

        bytes32 data = hash(choice, salt);
        reveal(data);

        player_choice[msg.sender] = choice;
        player_not_revealed[msg.sender] = false;

        numPlayerReveal++;

        if (numPlayerReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    function getMoneyBackAfter5Min() public {
        // if someone not commit the other can get money back
        require(numInput < 2);
        require(elapsedMinutes() >= 5 minutes);

        address payable account0 = payable (players[0]);
        address payable account1 = payable (players[1]);

        account0.transfer(reward/numPlayer);
        account1.transfer(reward - (reward/numPlayer));
        
        reward = 0;
    }

    function getMonetBackAfter10MinIfAnotherNotReveal() public {
        // if someone not reveal the other can get money back
        require(numInput == 2);
        require(numPlayerReveal < 2);
        require(elapsedMinutes() >= 10 minutes);
        
        address payable account0 = payable (players[0]);
        address payable account1 = payable (players[1]);

        if (player_not_revealed[players[0]]) {
            account1.transfer(reward);
        } else {
            account0.transfer(reward);
        }
        
        reward = 0;
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }
}
