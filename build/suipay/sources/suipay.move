/// Module: paypal
module suipay::suipay {
    use sui::transfer;
    use sui::object::{Self,UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    use sui::coin::{Self, Coin, value, split, destroy_zero};
    use sui::balance::{Self, Balance};
    use sui::pay;
    use sui::sui::SUI;
    use sui::event;

    public struct Username has store {
        name: vector<u8>,
        owner: address,
    }

    public struct User has key, store {
        id: UID,
        username: Username,
        listAddress: vector<address>,
        requests: vector<Request>,
        history: vector<SendReceive>
    }

    public struct Request has store, drop {
        name_requestor: vector<u8>,
        address_requestor: address,
        amount: u64,
        message: vector<u8>,
        name: vector<u8>
    }

    public struct SendReceive has store, drop {
        action: vector<u8>,
        amount: u64,
        message: vector<u8>,
        otherPartyAddress: address,
        otherPartyName: vector<u8>
    }

    public struct Paypal has key, store {
        id: UID,
        accounts: VecMap<vector<u8>, User>
    }

    public struct EventUserAdded has copy, drop {
        name: vector<u8>,
        owner: address,
    }

    public struct EventPaymentRequestCreated has copy, drop {
        requestor: vector<u8>,
        amount: u64,
        address: address,
        name: vector<u8>
    }

    public struct EventPaymentMade has copy, drop {
        receiver: vector<u8>,
        amount: u64,
        message: vector<u8>
    }

    public struct EventOwnershipRevoked has copy, drop {
        notification: vector<u8>
    }

    public struct EventWithDrawal has copy, drop {
        owner: vector<u8>,
        amount: u64
    }

    fun init(ctx: &mut TxContext) {
        let accounts= vec_map::empty<vector<u8>, User>();
        let paypal = Paypal {
            id: object::new(ctx),
            accounts,
        };
        let sender = ctx.sender();
        transfer::public_transfer(paypal, sender)        
    } 


    public entry fun add_user( name: vector<u8>, owner: address, paypal: &mut Paypal, ctx: &mut TxContext) {
        let sender = ctx.sender();
        let user = User {
            id: object::new(ctx),
            username: Username {
                name,
                owner
            },
            listAddress: vector::empty<address>(),
            requests: vector::empty<Request>(),
            history: vector::empty<SendReceive>(),
        };

        vec_map::insert(&mut paypal.accounts, name, user);
        event::emit(
            EventUserAdded {
                name: name,
                owner: owner
            }
        )

    }

    public entry fun create_request(paypal: &mut Paypal, name: vector<u8>, message: vector<u8>, amount: u64, requestor: vector<u8>, address: address) {
        let mut user = vec_map::get_mut(&mut paypal.accounts, &name);
        let request = Request {
            name_requestor: name,
            address_requestor: address,
            amount,
            message,
            name
        };
        user.requests.push_back(request);
        event::emit(
            EventPaymentRequestCreated {
                requestor,
                amount,
                address,
                name
            }
        )
    }


    public entry fun pay_request(
        paypal: &mut Paypal, 
        name: vector<u8>, 
        request_index: u64, 
        coin: &mut Coin<SUI>, 
        ctx: &mut TxContext
    ) {
        let sender_address = ctx.sender();
        let (receiver, address_requestor, payment_amount, message, sender_name) = handle_user_request(paypal, name, request_index);
        handle_requestor_payment(paypal, receiver, address_requestor, payment_amount, coin, sender_name, message, sender_address, ctx);

        event::emit(EventPaymentMade { 
            receiver, 
            amount: payment_amount, 
            message 
        });
    }

    
    fun handle_user_request(
        paypal: &mut Paypal, 
        name: vector<u8>, 
        request_index: u64
    ): (vector<u8>, address, u64, vector<u8>, vector<u8>) {
        let mut user = get_user(paypal, name);
        let request = vector::borrow_mut(&mut user.requests, request_index);
        let sender_name = user.username.name;
        let receiver = request.name_requestor;
        let address_requestor = request.address_requestor;
        let payment_amount = request.amount;
        let message = request.message;
        let sender_entry = SendReceive {
            action: b"-", 
            amount: payment_amount, 
            message, 
            otherPartyAddress: address_requestor, 
            otherPartyName: receiver
        };
        user.history.push_back(sender_entry);
        vector::remove(&mut user.requests, request_index);
        (receiver, address_requestor, payment_amount, message, sender_name)
    }

    fun handle_requestor_payment(
        paypal: &mut Paypal, 
        receiver: vector<u8>, 
        address_requestor: address, 
        payment_amount: u64, 
        coin: &mut Coin<SUI>,
        sender_name: vector<u8>,
        message: vector<u8>,
        sender_address: address,
        ctx: &mut TxContext
    ) {
        let mut requestor = get_user(paypal, receiver);
        pay::split_and_transfer(coin, payment_amount, address_requestor, ctx);
        let receive_entry = SendReceive {
            action: b"+", 
            amount: payment_amount, 
            message, 
            otherPartyAddress: sender_address, 
            otherPartyName: sender_name
        };
        requestor.history.push_back(receive_entry);
    }

    fun get_user(paypal: &mut Paypal, name: vector<u8>): &mut User {
        vec_map::get_mut(&mut paypal.accounts, &name)
    }



    















    



}

