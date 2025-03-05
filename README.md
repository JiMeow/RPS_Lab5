# RPS_Lab5

```solidity
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

    // เพิ่มผู้เล่นเข้่าไป
    function addPlayer() public payable {
        require(numPlayer < 2);

        // ล็อกคนที่เล่นได้มีแค่ 4 คน
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

        // ทำ flag ว่าไม่เคยเปืดเผย
        player_not_revealed[msg.sender] = true;

        players.push(msg.sender);
        numPlayer++;

        setStartTime();
    }

    // ให้ข้างนอกใช้ hash choice ก่อนจะ input
    function hash(uint choice, bytes32 salt) public pure returns (bytes32) {
        require(choice >= 0 && choice <= 4);

        // นำข้อความมาต่อกันแล้ว hash
        return getHash(keccak256(abi.encodePacked(choice, salt)));
    }

    // เลือก choice ที่ hash แล้วมาเก็บไว้ก่อน
    function input(bytes32 hashedInput) public  {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);

        บันทึกไว้
        commit(hashedInput);
        player_not_played[msg.sender] = false;

        numInput++;
    }

    // เปิดเผย choice ที่เลือกเพื่อตัดสินเกม
    function reveal(uint choice, bytes32 salt) public {
        require(numInput == 2);

        // นำไปแฮชเหมือนเดิม
        bytes32 data = hash(choice, salt);

        // เปิดเผยว่าบันทึกไว้จริงไหม
        reveal(data);

        // บันทึกว่าคนนั้นๆ ใช้ choice อะไรเพื่อตัดสินและมาร์กว่าเปิดเผยแล้ว
        player_choice[msg.sender] = choice;
        player_not_revealed[msg.sender] = false;

        numPlayerReveal++;

        // เปิดทั้งคู่คือจบเกมไปเช็คคนชนะ
        if (numPlayerReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    // ถ้ามีคนไม่ commit ภายใน 5 นาทีขอเงินคืนได้
    function getMoneyBackAfter5Min() public {
        // if someone not commit the other can get money back
        require(numInput < 2);
        require(elapsedMinutes() >= 5 minutes);

        address payable account0 = payable (players[0]);
        account0.transfer(reward);
        
        _resetGame();
    }

    // ถ้ามีคนไม่ reveal จะทำการยิดเงินภายใน 10 นาที
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
        
        _resetGame();
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        // เช็คคนชนะแบบ 5 choice
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
        _resetGame();
    }

    // reset game
     function _resetGame() private {
        numPlayer = 0;
        numPlayerReveal = 0;
        reward = 0;
        numInput = 0;

        // Clear all mappings
        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_played[players[i]];
            delete player_not_revealed[players[i]];
        }

        // Clear players array
        delete players;
    }
}
```


อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
```solidity
function getMoneyBackAfter5Min() public {
    // if someone not commit the other can get money back
    require(numInput < 2);
    require(elapsedMinutes() >= 5 minutes);

    address payable account0 = payable (players[0]);
    address payable account1 = payable (players[1]);

    account0.transfer(reward/numPlayer);
    account1.transfer(reward - (reward/numPlayer));
    
    _resetGame();
}
```
ทำให้สามารถถอนเงินได้หลังผ่านไป 5 นาทีหากอีกคนหนึ่งไม่ยอมเล่น
<br/>
<hr/>

อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit
```solidity
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

```
ข้อมูลที่เก็บใน smartcontract หรือส่งเข้าไปนั้นล้วน hash หมดแล้ว เมื่อทุกคนลงผลเสร็จจึงค่อยมาเปิดเผยผ่าน reveal
<br/>
<hr/>

อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที
```solidity
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
    
    _resetGame();
}
```
หากอีกคนหนึ่งไม่ยอม reveal หลังผ่านไป 10 นาทีเราจะสามารถถอนเงินทั้งหมดออกมาได้เลย เสมือนเป็นผู้ชนะ
<br/>
<hr/>

อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ
```solidity
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

    _resetGame();
}
```
ตัดสินใจโดยจะชนะเมื่อชอยส์เลื่อนไปข้างหน้า 1 หรือ 3 หน่วย โดยทั้งคู้ต้อง reveal ก่อนโดยทำการส่ง salt และ choice ของจริงเพื่อ reveal และตัดสิน
<br/>
<hr/>
