# Kaisho Pay Smart Contract

Kaisho Pay is a decentralized payment system built on the **Sui blockchain**. It enables users to send, receive, and manage payments seamlessly using cryptocurrencies. The smart contract provides functionalities such as payment requests, payment links, deposits, withdrawals, and more.

---

## 🌟 Features

- **User Management**: Create and manage user accounts with linked addresses.
- **Payment Requests**: Request payments from other users with custom messages and amounts.
- **Payment Links**: Generate payment links for easy and secure transactions.
- **Deposits & Withdrawals**: Deposit funds into your account and withdraw them as needed.
- **Transaction History**: Track all incoming and outgoing payments with detailed transaction history.
- **Multi-Currency Support**: Built to support SUI and other compatible tokens.
- **Event Logging**: Emits events for all major actions (e.g., payments, deposits, withdrawals).

---

## 📜 Smart Contract Overview

The Kaisho Pay smart contract is written in **Move**, the programming language for the Sui blockchain. It consists of the following key components:

### Structs
- **User**: Represents a user account with a username, balance, payment requests, and transaction history.
- **PaymentLink**: Represents a payment link that can be shared for easy payments.
- **Request**: Represents a payment request from one user to another.
- **SendReceive**: Represents a transaction entry in the user's history.
- **Kaisho Pay**: The main contract struct that stores all user accounts and owner mappings.

### Key Functions
- **add_user**: Create a new user account.
- **create_payment_link**: Generate a payment link for easy payments.
- **pay_via_payment_link**: Pay via a generated payment link.
- **deposit**: Deposit funds into a user's account.
- **create_request**: Create a payment request for another user.
- **pay_request**: Pay a pending payment request.
- **withdraw**: Withdraw funds from a user's account.
- **add_linked_address**: Add a linked address to a user's account.
- **remove_linked_address**: Remove a linked address from a user's account.

### Events
- **EventUserAdded**: Emitted when a new user is added.
- **EventPaymentLinkCreated**: Emitted when a payment link is created.
- **EventPaymentLinkPaid**: Emitted when a payment link is paid.
- **EventDepositMade**: Emitted when a deposit is made.
- **EventPaymentMade**: Emitted when a payment is made.
- **EventWithDrawal**: Emitted when a withdrawal is made.

---

## 🛠️ Getting Started

### Prerequisites
- **Sui Blockchain**: Ensure you have access to the Sui blockchain (testnet or mainnet).
- **Move Compiler**: Install the Move compiler to build and deploy the smart contract.

### Deployment
1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/Kaisho Pay.git
   cd Kaisho Pay
   ```
2. Compile the smart contract:
   ```bash
   sui move build
   ```
3. Deploy the contract to the Sui blockchain:
   ```bash
   sui client publish --gas-budget 10000
   ```

### Interacting with the Contract
- Use the Sui CLI or a frontend application to interact with the deployed contract.
- Call functions like `add_user`, `create_payment_link`, `deposit`, and `withdraw` to manage payments.

---

## 📜 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

---


---

**Empower your payments with Kaisho Pay and experience seamless Web3 transactions!**

