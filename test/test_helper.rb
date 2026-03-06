# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "tokenize_attr"

require "minitest/autorun"

# Establish an in-memory SQLite database for the test suite.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :records, force: true do |t|
    t.string :token
    t.string :api_key
    t.string :secret
    t.timestamps
  end
end

# Silence ActiveRecord query logging during tests.
ActiveRecord::Base.logger = nil
