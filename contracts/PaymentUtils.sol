pragma solidity ^0.8;

contract PaymentUtils {
    enum PaymentStatus{
        Locking, //锁定期
        Appealing, //仲裁中
        Executed,   //在申诉期，存在申诉，申诉被裁决及执行完成
        Paid    // 未被申诉时，正常支付完成
    }

    struct Payment {
        uint8 paymentType; // 支付类型 1 表示预支付
        address sender; //支付者地址
        address paymentToken; //支付代币，若没有该值，表示使用原声代币支付
        uint amount;//表示支付总金额（上限）
        address[] recipients; //接收者地址数量较少时，直接用数据存储
        uint256 lockTime; //锁定时间，有值时表示预支付，无值时表示即使支付（暂不实现）
        uint256 nonce; //表示支付顺序数
        PaymentStatus status;
    }
    Payment[] payments;
}