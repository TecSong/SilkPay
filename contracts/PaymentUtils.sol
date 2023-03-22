pragma solidity ^0.8.7;

contract PaymentUtils {
   enum PaymentStatus{
        Locking, //锁定期   
        Appealing, //仲裁中
        Executed,  //在申诉期，存在申诉，申诉被裁决及执行完成
        Paid,    // 没有仲裁时，正常支付完成
        ReFund   //没有仲裁，资金退回支付方
    }

    enum PaymentType{
        PrePay //预支付
    }

    struct Payment {
        uint8 paymentType; // 支付类型 0 表示预支付
        address sender; //支付者地址
        address paymentToken; //支付代币，若没有该值，表示使用原生代币支付
        uint256 amount;//表示支付总金额（上限）
        bool targeted;
        address recipient;
        // address[] participants; //接收者地址数量较少时，直接用数组存储
        bytes32 merkleTreeRoot; //null时使用participants，非null时，使用该值
        uint256 lockTime; //锁定时间，有值时表示预支付，无值时表示即使支付（暂不实现）
        //uint256 nonce; //表示支付顺序数
        uint256 startTime; //该笔支付开始的时间，用于计算缓冲期、仲裁过程中的时间约束等
        PaymentStatus status; //支付状态
    }
}