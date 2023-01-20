# Test dm graphql api

This repo contains the metadata and migrations for a test dm GraphQL API.  Note that the GraphQL Server is running on Hasura cloud, whose Engine made automatically resolvers on top of a Postgres DB. 

This API allows: 

 1. Create a user 
 2. Create a conversation (i.e a conversation is a channel that a user is subscribed to. A DM between 2 people would be 1 conversation with two users subscribed to it. A conversation can host any number of users, including 1 user, where a person can message themselves)
 3. Retrieve conversations that a user is engaged in
 4. Retrieve message in a conversation 
 5. Sending messages
 6. Keep track of online status

**API Endpoint:** https://test-dms.hasura.app/v1/graphql

**Secret-key:** ayHkGqEx09jkYgJ0tWUaeGd2161LTVvyqXo9TySWrFx1tP90njS9HNH7c8RtpepG (Normally, this should be kept a secret, but in this context we don't care)


## Why a GraphQL API? 

 - Flexible (it's a query standard)
	 -  client decides what data it wants and how, which is very different from REST framework where endpoints are rigid
 - Robust
	 -  websockets based interactions such as subscription and streams
	 - streams in particular makes sense for a chat application as they are stateful and designed to give new objects. 
	

## Getting started With a local Hasura GUI

1. Clone this repo 
2. run `npm install --global hasura-cli` to install the Hasura CLI
3. Set the env variables as shown in the .example.env (the env variables should be based on development) 
4. run `hasura console` .  You should see the Hasura GUI, where you can test out queries

**Note:** The local Hasura GUI has a GraphiQL environment where you can try out queries.

##  Models 

### Users

A user with basic information stores information such as last_seen and last_typed. 

    user (
	    id SERIAL PRIMARY KEY
	    username TEXT UNIQUE
	    last_seen timestamp with time zone
	    last_typed timestamp with time zone
	    )
     
### Conversations
A conversation-users is a table that shows who is engaged in what conversation and what their status is in that conversation. 

    conversation_users (
	    conversation_id INT PRIMARY KEY
	    user_id INTE PRIMARY KEY FOREIGN KEY REFERENCES user(id)
	    status TEXT FOREIGN KEY REFERENCES conversation_status(value) 
	    )

**Note:** status is an enum with options of state of a conversation of a user. the status can be rejected, invited, live, or closed. A user can be invited to a new conversation, they can reject the invitation, they can accept and go live or close the conversation all together. 

### Messages   

Messages is some text written by a user in a conversation and everyone in a conversation gets has access to that message. 

    messages (
	    id SERIAL NOT NULL PRIMARY KEY
	    "message" TEXT NOT NULL
	    author_id INT FOREIGN KEY REFERENCES user(id) NOT NULL
	    )
## Usage 

**To use, this GraphQL API, one needs a GraphQL API client**. Example of one in js is [Apollo GraphQL Client.](https://www.apollographql.com/docs/react/) Depending on your platform choice for the client, one should get an appropriate client. 

### Create a user 
A GraphQL mutation to create a user:

    mutation add_user ($username: String!) {
      insert_user_one(object: { username: $username }) {
        id
        username
      }
    }

### Start a conversation 
Start a conversation between two users:  

    mutation create_conversation($conversation_id: Int!, $conversation_requester: Int!, $conversation_requestee: Int!) {
      insert_conversation_users_many(objects: [{conversation_id: $conversation_id, user_id: $conversation_requester, status: live},{conversation_id: $conversation_id, user_id: $conversation_requestee, status: invited} ]) {
        user_id
      }
    }

For a group, you could have more than conversation_user object in “objects.”

### Reject a conversation 
A mutation to reject a conversation
	
    mutation update_conversation($_eq: Int!, $_eq1: Int!) {
      update_conversation_users(where: {conversation_id: {_eq: $_eq}, _and: {user_id: {_eq: $_eq1}}}, _set: {status: rejected}) {
        affected_rows
      }
    }

### Retrieve conversations
Retrieve conversation through a GraphQL subscription: 

    subscription retrieve_conversations ($_eq: Int!) {
      conversation_users(where: {user_id: {_eq: $_eq}}) {
        conversation_id
        status
        user_id
      }
    }
Note: This uses a subscription because a live update makes sense in this situation, as the user might want to see conversation requests come in without refreshing.

### Stream messages

Streaming new messages though a GraphQL stream: 

    subscription stream_messages ($start_value) {
      messages_stream(cursor: {initial_value: {id: $start_value }}, batch_size: 5) {
        id
        message
        author_id
      }
    }

**In this case, we use a stream instead of a regular subscription because streams are stateful, which means in this case you would be able to get just the new messages for a given user.** 

Note that to use this stream, you will have to set **'x-hasura-user-id'** to the user  you are interested in getting messages for. 

### Send messages 

A GraphQL mutation to send a message: 

    mutation write_message ($author_id: Int!, $conversation_id: Int!, $message: String!, $id: Int!) {
      insert_messages_one(object: {author_id: $author_id, conversation_id: $conversation_id, message: $message, id: $id}) {
        message
        id
        conversation_id
        author_id
      }
    }

### Update online status

A GraphQL mutation to update online status: 

	    mutation ($userId: Int!) {
	      update_user_by_pk(
	        pk_columns: { id: $userId }
	        _set: { last_seen: "now()" }
	      ) {
	        id
	      }
	}

A GraphQL mutation to subscribe to people who are online at the moment: 

     subscription {
      user_online(order_by: { username: asc }) {
        id
        username
      }
    }

## Future improvements

1. Conversation_users allows users to have multiple dms for now
2. Someone can write a message to a conversation that they are not in!
3. A user can't delete, and it would be very difficult to support delete functionality with the database schema 
4. User_typing doesn't help here because it would be good to know in which conversation is a user typing in. [saw this later than I should have] 


## Inspirations

https://github.com/hasura/graphql-engine/tree/master/community/sample-apps/streaming-subscriptions-chat
https://hasura.io/blog/building-real-time-chat-apps-with-graphql-streaming-subscriptions/
