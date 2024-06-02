/// Module: paypal
#[allow(unused_use)]
module paypal::suipay {
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::object::{Self,UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    

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
        accounts: vector<VecMap<vector<u8>, User>>
    }

    public struct EventUserAdded has copy, store {
        name: vector<u8>,
        owner: address,
    }

    public struct EventPaymentRequestCreated has copy, store {
        requestor: vector<u8>,
        amount: u64,
        name: vector<u8>
    }

    public struct EventPaymentMade has copy, store {
        receiver: vector<u8>,
        amount: u64,
        message: vector<u8>
    }

    public struct EventOwnershipRevoked has copy, store {
        notification: vector<u8>
    }

    public struct EventWithDrawal has copy, store {
        owner: vector<u8>,
        amount: u64
    }

    fun init(ctx: &mut TxContext) {
        let accounts= vector::empty<VecMap<vector<u8>, User>>();
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

        let mut userMap = vec_map::empty<vector<u8>, User>();
        vec_map::insert(&mut userMap, name, user);
        paypal.accounts.push_back(userMap);

    
        // transfer::public_transfer(user, sender);
    }

    









}

