require 'json'

module DfE
  module Wizard
    # The wizard's changeset: gem state kept beside the answers.
    #
    # A plain object over the wizard's state store. Its fields live under
    # one reserved top-level key, `_dfe_wizard`, written through
    # `state_store.write` like any answer. The answers stay where they are.
    # In this release the only field is the change journey state.
    #
    # Building a changeset reads and writes nothing, so a wizard that does
    # not use change journeys is unaffected.
    #
    # @example
    #   snapshot = wizard.changeset.answers
    #   # ... the user changes funding_type ...
    #   wizard.changeset.answer_changes_since(snapshot) # => [:funding_type]
    #
    # @api public
    class Changeset
      # The reserved top-level key
      KEY = :_dfe_wizard

      # @param wizard [DfE::Wizard]
      def initialize(wizard)
        @wizard = wizard
        @write_checked = false
      end

      # The current answers: step attributes only, normalised
      #
      # Keys are symbols. Values have been through a JSON round trip, so a
      # value read back from any repository compares equal.
      #
      # @return [Hash{Symbol => Object}]
      def answers
        names = answer_names
        read = state_store.read
        picked = {}
        read.each do |key, value|
          name = key.to_sym
          next unless names.include?(name)
          next if picked.key?(name) && !key.is_a?(Symbol)

          picked[name] = value
        end
        normalise(picked)
      end

      # Answers that differ from a snapshot
      #
      # Changed, added or removed answers, in attribute_names order. Other
      # keys (metadata, `_dfe_wizard`) are ignored. Both sides are
      # normalised the same way.
      #
      # @param snapshot [Hash] answers, as returned by #answers
      # @return [Array<Symbol>]
      def answer_changes_since(snapshot)
        before = normalise(snapshot || {})
        after = answers
        answer_names.reject { |name| before[name] == after[name] }
      end

      # The change journey state, or nil when there is none
      #
      # @return [Hash, nil]
      # @api private
      def journey
        fields[:journey]
      end

      # Replace the change journey state
      #
      # @param state [Hash, nil] nil ends the journey
      # @return [void]
      # @raise [ArgumentError] for a repository that cannot hold a changeset
      # @api private
      def journey=(state)
        check_repository!
        write_fields(fields.merge(journey: state))
      end

      private

      def fields
        stored = stored_value(state_store.read)
        stored.is_a?(Hash) ? normalise(stored) : {}
      end

      # Writes nil first, so a deep-merging repository (InMemory) keeps
      # no field from the old value. Callers check the repository first.
      def write_fields(new_fields)
        state_store.write(KEY => nil)
        state_store.write(KEY => normalise(new_fields))
        check_written!
      end

      def stored_value(read)
        read.key?(KEY) ? read[KEY] : read[KEY.to_s]
      end

      def check_repository!
        if state_store.repository.is_a?(Repository::Model)
          raise ArgumentError, 'Repository::Model cannot hold a changeset'
        end
        return unless state_store.respond_to?(:default_repository?) && state_store.default_repository?

        raise ArgumentError,
              'change journeys need a repository that keeps data between requests; ' \
              'the state store was built without one'
      end

      def check_written!
        return if @write_checked

        if stored_value(state_store.read).nil?
          raise ArgumentError,
                "the repository dropped #{KEY}; check transform_for_read and transform_for_write"
        end

        @write_checked = true
      end

      def answer_names
        @answer_names ||= @wizard.attribute_names.map(&:to_sym).uniq
      end

      def normalise(value)
        JSON.parse(JSON.generate(value), symbolize_names: true)
      end

      def state_store
        @wizard.state_store
      end
    end
  end
end
