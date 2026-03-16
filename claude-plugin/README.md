# tokenize_attr — Claude Code Plugin

A Claude Code plugin that teaches Claude how to install and use the
`tokenize_attr` gem in any Rails project.

## What's Included

```
claude-plugin/
├── .claude-plugin/
│   └── plugin.json                          # Plugin metadata
└── skills/
    └── tokenize-attr/
        ├── SKILL.md                         # Core skill — auto-loaded when relevant
        ├── references/
        │   ├── installation.md              # Step-by-step setup guide
        │   └── patterns.md                  # Usage patterns and recipes
        └── examples/
            ├── activerecord.rb              # AR model examples
            └── testing.rb                   # Minitest + RSpec test patterns
```

## Installing the Plugin

### Option A — Point Claude Code at the plugin directory

```bash
# One-off session
claude --plugin-dir /path/to/token_attr/claude-plugin

# Or copy the plugin directory to your project
cp -r /path/to/token_attr/claude-plugin /your/project/.claude-plugins/tokenize-attr
```

### Option B — Install globally in `~/.claude`

```bash
mkdir -p ~/.claude/plugins/tokenize-attr
cp -r /path/to/token_attr/claude-plugin/* ~/.claude/plugins/tokenize-attr/
```

## How the Skill Activates

The skill automatically activates when you ask Claude things like:

- "Add tokenize_attr to this project"
- "Install tokenize_attr"
- "Generate a secure token for my model attribute"
- "Add a prefixed token like `tok-abc123` to AccessToken"
- "Create an API key with a custom prefix"
- "Use `has_secure_token` with a prefix"
- "Add a custom token generator in Rails"
- "Handle `RetryExceededError` from tokenize_attr"

Claude will then know:

1. How to add the gem and run the installer
2. When `tokenize` delegates to `has_secure_token` vs. uses the callback
3. How to use `prefix:`, `size:`, `retries:`, and custom generators
4. That `retries:` is ignored on the `has_secure_token` path
5. That any generator always bypasses `has_secure_token`
6. How to write tests, including collision simulation via anonymous subclasses
