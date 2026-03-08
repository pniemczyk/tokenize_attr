# frozen_string_literal: true

require "tokenize_attr/installer"

namespace :tokenize_attr do
  INITIALIZER_RELATIVE = TokenizeAttr::Installer::INITIALIZER_PATH.to_s

  desc "Install an initializer that auto-includes TokenizeAttr::Concern into ActiveRecord"
  task :install do
    result = TokenizeAttr::Installer.install!(Rails.root)

    case result
    when :created then printf "  %-10s %s\n", "create", INITIALIZER_RELATIVE
    when :skipped then printf "  %-10s %s\n", "skip",   "#{INITIALIZER_RELATIVE} already exists"
    end
  end

  desc "Remove the tokenize_attr initializer"
  task :uninstall do
    result = TokenizeAttr::Installer.uninstall!(Rails.root)

    case result
    when :removed then printf "  %-10s %s\n", "remove", INITIALIZER_RELATIVE
    when :skipped then printf "  %-10s %s\n", "skip",   "#{INITIALIZER_RELATIVE} not found"
    end
  end
end
