# tokenize_attr — LLM Context Overview

> Load this file before modifying or extending the gem.

## Purpose

`tokenize_attr` is a Ruby gem that provides declarative secure token generation
for ActiveRecord model attributes via a single `tokenize` class macro.

---

## Public API

```ruby
# Full signature
tokenize(attribute, generator = nil, size: 64, prefix: nil, retries: 3, &block)
```

| Param       | Type             | Default | Notes                                              |
|-------------|------------------|---------|----------------------------------------------------|
| `attribute` | Symbol           | —       | The attribute to tokenize                          |
| `generator` | Proc / nil       | nil     | Called as `generator.call(size)` for random part.  |
|             |                  |         | May also be supplied as a `&block`.                |
| `size`      | Integer          | 64      | Passed to generator or to `SecureRandom.base58`    |
| `prefix`    | String / nil     | nil     | Prepended as `"prefix-<token>"`                    |
| `retries`   | Integer          | 3       | Max uniqueness-check attempts (callback path only) |

---

## Internal decision tree

All logic below lives in `TokenizeAttr::Tokenizer` (see
`lib/tokenize_attr/tokenizer.rb`). `TokenizeAttr::Concern#tokenize` is a thin
delegator that calls `TokenizeAttr::Tokenizer.apply`.

```
tokenize called  →  TokenizeAttr::Tokenizer.apply(klass, attribute, ...)
  └─ generator nil? AND prefix nil? AND has_secure_token available?
       ├─ YES → Tokenizer.via_has_secure_token(klass, attribute, size)
       │          tries: klass.has_secure_token(attribute, length: size)
       │          rescue ArgumentError → klass.has_secure_token(attribute)
       │          (retries param is IGNORED on this path)
       │
       └─ NO  → Tokenizer.via_callback(klass, attribute, size:, prefix:, retries:, generator:)
                  klass.before_create:
                    attribute.present? → skip
                    loop retries times:
                      random_part = generator ? generator.call(size)
                                              : SecureRandom.base58(size)
                      candidate = [prefix, random_part].compact.join("-")
                      assign candidate to attribute
                      exists?(attribute => candidate)? → next iteration
                      else → token_generated = true; break
                    token_generated? → done
                    else → raise RetryExceededError
```

---

## Error class hierarchy

```
StandardError
  └── TokenizeAttr::Error
        └── TokenizeAttr::RetryExceededError
```

---

## Key constraints

- Only `activesupport` is a hard runtime dependency.
- `ActiveRecord::Base` receives the concern via `ActiveSupport.on_load(:active_record)`.
- All generation helpers live in `TokenizeAttr::Tokenizer`, not in the model
  class. This prevents method-name collisions on user models. Only the
  `tokenize` macro is mixed in via `Concern`.
- Tests use bare `activerecord` + SQLite3 — no `rails` gem.
- `has_secure_token` delegation is skipped when `prefix:` is provided
  because that built-in has no prefix support.
- `has_secure_token` delegation is also skipped when a `generator` is
  provided — the generator always routes through the callback path.
