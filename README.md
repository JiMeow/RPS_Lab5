# RPS_Lab5

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
