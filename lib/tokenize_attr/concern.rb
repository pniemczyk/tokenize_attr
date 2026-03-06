# frozen_string_literal: true

module TokenizeAttr
  # Include this concern in any ActiveRecord model (or any class that
  # provides +before_create+ and a class-level +exists?+ predicate) to gain
  # the +tokenize+ class macro.
  #
  # When Rails is loaded the concern is auto-included into
  # +ActiveRecord::Base+ via an +ActiveSupport.on_load+ hook, so explicit
  # inclusion is not needed in Rails apps.
  #
  # All generation logic is delegated to +TokenizeAttr::Tokenizer+ so that no
  # internal helpers are mixed into the model class.
  module Concern
    extend ActiveSupport::Concern

    class_methods do
      # Configures secure token generation for +attribute+.
      #
      # When +prefix+ is +nil+ *and* no +generator+ is given *and* the
      # including class responds to +has_secure_token+ (Rails 5+), the
      # Rails built-in is used. Note: +retries+ is ignored in that path
      # because +has_secure_token+ relies on DB constraints rather than
      # an application-level uniqueness check.
      #
      # Otherwise a custom +before_create+ callback is installed. All
      # implementation details live in +TokenizeAttr::Tokenizer+.
      #
      # @param attribute  [Symbol]            the attribute to assign the token to
      # @param generator  [Proc, nil]         optional callable invoked as
      #   +generator.call(size)+ to produce the random portion of the token.
      #   May also be supplied as a block.  When present the custom callback
      #   path is always used, even when +has_secure_token+ is available.
      # @param size       [Integer]           length passed to the generator or
      #   to +SecureRandom.base58+ (default 64)
      # @param prefix     [String, nil]       optional prefix, joined as
      #   +"prefix-<token>"+
      # @param retries    [Integer]           max uniqueness-check retries
      #   (default 3); ignored on the +has_secure_token+ path
      #
      # @raise [TokenizeAttr::RetryExceededError] when uniqueness cannot be
      #   established within the retry budget
      #
      # @example Delegate to has_secure_token (no prefix, no generator)
      #   class User < ApplicationRecord
      #     tokenize :api_token
      #   end
      #
      # @example Custom callback with prefix
      #   class AccessToken < ApplicationRecord
      #     tokenize :token, size: 32, prefix: "tok"
      #   end
      #
      #   AccessToken.create!.token #=> "tok-aBcD1234..."
      #
      # @example Proc passed as second argument
      #   class Order < ApplicationRecord
      #     tokenize :reference, proc { |size| SecureRandom.alphanumeric(size) },
      #              prefix: "ord", size: 12
      #   end
      #
      # @example Method reference via &
      #   class Order < ApplicationRecord
      #     def self.reference_generator(size) = SecureRandom.alphanumeric(size)
      #     tokenize :reference, &method(:reference_generator)
      #   end
      #
      # @example Inline block
      #   class Order < ApplicationRecord
      #     tokenize(:reference) { |size| SecureRandom.alphanumeric(size) }
      #   end
      def tokenize(attribute, generator = nil, size: 64, prefix: nil, retries: 3, &block)
        TokenizeAttr::Tokenizer.apply(
          self, attribute,
          generator: generator || block,
          size: size,
          prefix: prefix,
          retries: retries
        )
      end
    end
  end
end
