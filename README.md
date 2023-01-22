#  pongo

Use pongo from the command line: pongo is helpfully configured to print in yellow all the JSON that will be sent along the `/updates` path as it runs.

- install %pongo desk in two or more ships. i'll be using `~tes` and `~dev`

- on `~tes`, run: `:pongo|new 'squidchat72' ~[~dev]`. you will see a conversation id appear.

- on `~dev`, run: `:pongo|join <conversation-id>`

- on either ship, you can now send message like so:
  `:pongo|message <conversation-id> 'your message'`

- you can edit messages you've previously sent like so:
  `:pongo|edit <conversation-id> <message-id> 'new message text'`

- you can react to messages you've seen:
  `:pongo|react <conversation-id> <message-id> '🦑'`

- you can leave a conversation:
  `:pongo|leave <conversation-id>`

The yellow "sending" receipts mean that a message was processed by your urbit ship and sent out to other members of the conversation. This could be interpreted as "sent" in the user-facing display as an indicator that they are in fact connected to their urbit backend.

The yellow "delivered" receipts mean that a message was received (not seen, but deposited into their urbit ship) by *all* members in a conversation. This feature is currently artificially limited to conversations with 5 or fewer members. Try turning off one fakeship and sending messages to see how this works in practice. **Note**: ships that have us blocked will still send "delivered" receipts, but will not save or ever see the actual message.

Reactions are not limited to emojis, or validated in any way. I should add some handling around that. You can react again to the same message to override your existing reaction if any. Removing a reaction should probably just be reacting with an empty ''.

You can block and unblock ships from messaging you with these pokes:
- `{"block":{"who":"~bus"}}`
- `{"unblock":{"who":"~bus"}}`

For structure of all pokes see `/mar/pongo/action.hoon`.

To see the JSON representation of scries, use these in dojo:
- `(crip (en-json:html .^(json %gx /=pongo=/all-messages/<conversation-id>/json)))`
- `(crip (en-json:html .^(json %gx /=pongo=/conversations/json)))`

**Note**: leaving a conversation does *not* delete its record in the database, so you will still be able to scry a read-only archive of it. We can add a way to permanently delete these later!

I will add more specific scries very soon.