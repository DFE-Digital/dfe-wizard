# Loaded standalone by dfe-wizard.gemspec via require_relative, so this file
# must not depend on the rest of the library.
module DfE
  module Wizard
    VERSION = '1.0.0'.freeze
  end
end

# Releases up to 1.0.0.beta spelled this namespace `Dfe` (lowercase `e`), which
# never matched the `DfE` the rest of the library uses. Aliased rather than
# redefined, so `Dfe::Wizard` is the same module object as `DfE::Wizard` instead
# of an empty lookalike holding only VERSION. `DfE` is the canonical spelling.
Dfe = DfE unless defined?(Dfe)
