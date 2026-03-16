# tokenize_attr

Declarative secure token generation for ActiveRecord model attributes.

`tokenize_attr` adds a `tokenize` class macro to ActiveRecord models. When no
prefix is needed it transparently delegates to Rails' built-in
`has_secure_token` (Rails 5+). When a prefix is required — or when
`has_secure_token` is unavailable — it installs a `before_create` callback
backed by `SecureRandom.base58` with configurable size, prefix, and retry
logic.

## Installation

Add to your Gemfile:

```ruby
gem "tokenize_attr"
```

Then run the install task to wire the gem into your Rails app:

```bash
rails tokenize_attr:install
```

This creates `config/initializers/tokenize_attr.rb`, which calls
`ActiveSupport.on_load(:active_record)` so that every model gains the
`tokenize` macro automatically.

To remove the initializer:

```bash
rails tokenize_attr:uninstall
```

## Usage

### Basic — delegates to `has_secure_token`

When no prefix is provided and the model supports `has_secure_token` (every
Rails 5+ `ApplicationRecord`), the built-in Rails implementation is used
automatically.

```ruby
class User < ApplicationRecord
  tokenize :api_token
end

user = User.create!
user.api_token # => "aBcD1234..." (64 base58 chars by default)
```

### With prefix

When a `prefix:` is given the gem installs its own `before_create` callback.

```ruby
class AccessToken < ApplicationRecord
  tokenize :token, prefix: "tok", size: 32
end

AccessToken.create!.token # => "tok-aBcD1234..." ("tok-" + 32 random chars)
```

### Custom size (no prefix)

```ruby
class Session < ApplicationRecord
  tokenize :session_id, size: 128
end
```

### Custom retry budget

```ruby
class InviteCode < ApplicationRecord
  # Retry up to 5 times before raising TokenizeAttr::RetryExceededError
  tokenize :code, prefix: "inv", retries: 5
end
```

### Custom generator

Pass any callable as the second argument (or as a block) to replace
`SecureRandom.base58` with your own algorithm. The callable receives `size`
and must return a String.

```ruby
# Proc as second positional argument
class Order < ApplicationRecord
  tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
           prefix: "ord", size: 12
end

Order.create!.reference # => "ord-aB3cD4eF5gH6"
```

```ruby
# Method reference via &
class Order < ApplicationRecord
  def self.reference_generator(size) = SecureRandom.alphanumeric(size)
  tokenize :reference, &method(:reference_generator)
end
```

```ruby
# Inline block (parentheses required)
class Order < ApplicationRecord
  tokenize(:reference) { |size| SecureRandom.alphanumeric(size) }
end
```

> **Note:** Providing a generator always uses the callback path — even when
> no `prefix:` is given. The generator takes precedence over
> `has_secure_token`.

### Multiple tokenized attributes

```ruby
class ApiCredential < ApplicationRecord
  tokenize :public_key,  prefix: "pk", size: 32
  tokenize :private_key, prefix: "sk", size: 64
end
```

## Options

| Option      | Default | Description                                                      |
|-------------|---------|------------------------------------------------------------------|
| `generator` | `nil`   | Proc/block called as `generator.call(size)` → String.            |
|             |         | Overrides the default `SecureRandom.base58` algorithm.           |
| `size`      | `64`    | Length passed to the generator or to `SecureRandom.base58`.      |
| `prefix`    | `nil`   | String prepended as `"prefix-<token>"`.                          |
| `retries`   | `3`     | Max uniqueness-check attempts (custom callback path only).       |

> **Note:** `retries` is ignored when delegating to `has_secure_token`
> because Rails does not perform uniqueness checks there. Use a DB unique
> index to enforce uniqueness and let the DB raise on collision.

## Error handling

When the custom callback exhausts all retry attempts it raises
`TokenizeAttr::RetryExceededError` (a subclass of `TokenizeAttr::Error <
StandardError`).

```ruby
begin
  InviteCode.create!
rescue TokenizeAttr::RetryExceededError => e
  Rails.logger.error(e.message)
  # => "Could not generate a unique token for :code after 5 retries"
end
```

## Rails integration

Run `rails tokenize_attr:install` once after adding the gem. The generated
initializer (`config/initializers/tokenize_attr.rb`) hooks into
`ActiveSupport.on_load(:active_record)` so every model gains the `tokenize`
macro without an explicit include.

For non-Rails classes that provide `before_create` and `exists?` include the
concern manually:

```ruby
class MyModel
  include TokenizeAttr::Concern
end
```

## Recommended migration

Add a unique index on tokenized columns to enforce uniqueness at the DB
level:

```ruby
add_column :access_tokens, :token, :string
add_index  :access_tokens, :token, unique: true
```

## Claude Code Plugin

`tokenize_attr` ships with a Claude Code skill that teaches Claude how to install
and use the gem in any Rails project.

### Install the skill

Download `tokenize-attr.skill` from the releases page and import it into Claude Code:

```bash
claude skill install tokenize-attr.skill
```

Or copy the `claude-plugin/` directory into your project:

```bash
cp -r /path/to/token_attr/claude-plugin /your/project/.claude-plugins/tokenize-attr
```

### What the skill teaches Claude

Once installed, the skill activates automatically when you ask things like:

- "Add tokenize_attr to this project"
- "Add a prefixed token like `tok-abc123` to my model"
- "Generate a secure API key with a custom prefix"
- "Use `has_secure_token` with a prefix"
- "Add a custom token generator in Rails"
- "Handle `RetryExceededError` from tokenize_attr"

Claude will know when `tokenize` delegates to `has_secure_token` vs. uses its
own callback, how to use `prefix:`, `size:`, `retries:`, and custom generators,
and how to write tests including collision simulation.

---

## Development

```bash
bin/setup              # install dependencies
bundle exec rake test  # run the test suite
bin/console            # interactive prompt
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/pniemczyk/tokenize_attr.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
