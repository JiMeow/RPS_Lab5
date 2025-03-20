
// SPDX-License-Identifier: GPL-3.0

import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "./ERC20.sol";

pragma solidity >=0.7.0 <0.9.0;

contract RPS is CommitReveal, TimeUnit, ERC20 {
    uint public numPlayer = 0;
    uint public numPlayerReveal = 0;
    uint public reward = 0;

    mapping(address => uint) private player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors , 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    mapping(address => bool) public player_not_revealed;

    address[] public players;

    uint public numInput = 0;
    uint private cost = 0.000001 ether;

    function addPlayer() public payable {
        require(numPlayer < 2);
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }

        require(allowance[msg.sender][address(this)] == cost);

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

    function input(bytes32 hashedInput) payable public  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);

        commit(hashedInput);
        
        transferFrom(players[0], address(this), cost);
        transferFrom(players[1], address(this), cost);
        reward += cost;
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

    function getMoneyBackAfter10MinIfAnotherNotReveal() public {
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
    }

    function getMoneyBackIfNoOneReveal() public {
        require(numInput == 2);
        require(numPlayerReveal == 0);
        require(elapsedMinutes() >= 10 minutes);

        if (player_not_revealed[players[0]] && player_not_played[players[1]]) {
            address payable newGuy = payable (msg.sender);
            newGuy.transfer(cost * 2);
        }
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
