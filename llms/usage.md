# tokenize_attr — Usage Patterns

> Common patterns and recipes for LLMs helping users work with this gem.

---

## Basic (no prefix) — delegates to `has_secure_token`

```ruby
class User < ApplicationRecord
  tokenize :api_token
end

user = User.create!
user.api_token # => "aBcD1234..." (64 base58 chars)
```

`has_secure_token` is used automatically. `retries` is ignored on this path.

---

## With prefix — uses custom callback

```ruby
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end

token = AccessToken.create!
token.token # => "tok-aBcD1234..." ("tok-" + 32 random chars)
```

---

## Custom size (no prefix)

```ruby
class Session < ApplicationRecord
  tokenize :session_id, size: 128
end
```

---

## Custom retry budget

```ruby
class InviteCode < ApplicationRecord
  tokenize :code, prefix: "inv", retries: 5
end
```

---

## Handling `RetryExceededError`

```ruby
begin
  InviteCode.create!
rescue TokenizeAttr::RetryExceededError => e
  Rails.logger.error("Token generation failed: #{e.message}")
  # => "Could not generate a unique token for :code after 5 retries"
end
```

---

## Custom generator — proc as second argument

```ruby
class Order < ApplicationRecord
  tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
           prefix: "ord", size: 12
end

Order.create!.reference # => "ord-aB3cD4eF5gH6"
```

The proc receives `size` and must return a String. The `prefix` is still
applied on top of whatever the proc returns.

---

## Custom generator — method reference via `&`

```ruby
class Order < ApplicationRecord
  def self.reference_generator(size)
    SecureRandom.alphanumeric(size)
  end

  tokenize :reference, &method(:reference_generator)
end
```

`method(:reference_generator)` converts the class method to a `Method`
object which responds to `call(size)`. This is identical to passing a proc.

---

## Custom generator — inline block

```ruby
class Order < ApplicationRecord
  # Parentheses required when passing a block to a method call inside a class
  tokenize(:reference) { |size| SecureRandom.alphanumeric(size) }
end
```

---

## Custom generator with no prefix — bypasses `has_secure_token`

Providing any generator always uses the callback path, even when no `prefix:`
is given and `has_secure_token` is available:

```ruby
class User < ApplicationRecord
  tokenize :api_token, proc { |size| "usr_#{SecureRandom.hex(size / 2)}" }
end
```

---

## Multiple tokenized attributes

```ruby
class ApiCredential < ApplicationRecord
  tokenize :public_key,  prefix: "pk", size: 32
  tokenize :private_key, prefix: "sk", size: 64
end
```

---

## Manual inclusion (non-Rails or non-AR classes)

```ruby
class MyModel
  include TokenizeAttr::Concern

  # Provide before_create and self.exists? for the concern to work.
end
```

---

## Recommended migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_token_to_access_tokens.rb
class AddTokenToAccessTokens < ActiveRecord::Migration[7.1]
  def change
    add_column :access_tokens, :token, :string
    add_index  :access_tokens, :token, unique: true
  end
end
```

---

## Checking which path `tokenize` will use

```ruby
# In a Rails console or script:
MyModel.respond_to?(:has_secure_token) # => true/false
# true  → tokenize without prefix will use has_secure_token
# false → tokenize always uses the custom callback
```

---

## Preserving a pre-set token

The callback checks `present?` before generating, so a pre-set value is
always preserved:

```ruby
token = AccessToken.create!(token: "tok-my-custom-value")
token.token # => "tok-my-custom-value"
```
