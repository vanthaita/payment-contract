/// Module: paypal
module suipay::suipay {
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::object::{Self,UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use std::vector;
    use sui::vec_map::{Self, VecMap};
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

    public struct Request has key, store {
        id: UID,
        requestor: vector<u8>,
        amount: u64,
        message: vector<u8>,
        name: vector<u8>
    }

    public struct SendReceive has key, store {
        id: UID,
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

    public struct EventUserAdded has copy, store {
        name: vector<u8>,
        owner: address,
    }

    public struct EventPaymentRequestCreated has copy, drop {
        requestor: vector<u8>,
        amount: u64,
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


    public fun addUser(ctx: &mut TxContext, name: vector<u8>, owner: address, paypal: &mut Paypal) {
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
    }

    public fun pay_request(ctx: &mut TxContext, paypal: &mut Paypal, name: vector<u8>, request_index: u64) {
        let sender = ctx.sender();
        let mut user = vec_map::get_mut(&mut paypal.accounts, &name);
        let request = vector::borrow_mut(&mut user.requests, request_index);
        let payment_amount = request.amount;
        let receiver = request.requestor;
        event::emit(EventPaymentMade{ receiver, amount: payment_amount, message: request.message })
        // coin transfer to requestor
    }


    

















    



}

