require 'json'

module DfE
  module Wizard
    # The wizard's changeset: gem state kept beside the answers.
    #
    # A plain object over the wizard's state store. Its fields live under
    # one reserved top-level key, `_dfe_wizard`, written through
    # `state_store.write` like any answer. The answers stay where they are.
    # The fields are the change journey state and, for an edit of a saved
    # record, the seed, the record's `updated_at`, the record identity and
    # the caller URL.
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

      # Seed the changeset with the answers of a saved record
      #
      # Runs once, on a new state_key: the metadata first (read back to
      # check the repository kept it), then the answers.
      #
      # @param answers [Hash] answers in step attribute names
      # @param updated_at [Time, nil] the record's updated_at
      # @return [void]
      # @raise [ArgumentError] for a repository that cannot hold a changeset,
      #   or when the store already holds data
      def seed!(answers, updated_at: nil)
        check_repository!
        unless state_store.read.empty?
          raise ArgumentError, 'the changeset is not empty; seed! runs once, on a new state_key'
        end

        write_fields(edit: { seed: answers, updated_at: stamp(updated_at) })
        state_store.write(answers)
      end

      # The seeded answers
      #
      # @return [Hash{Symbol => Object}] deep symbol keys; {} for a draft
      def seed
        edit_fields[:seed] || {}
      end

      # The record's updated_at when it was seeded
      #
      # @return [String, nil] iso8601(6), in UTC
      def seed_updated_at
        edit_fields[:updated_at]
      end

      # Whether the changeset holds an edit of a saved record
      #
      # @return [Boolean]
      def edit?
        !fields[:edit].nil?
      end

      # Answers on the path that differ from the seed
      #
      # Answers for steps that left the path are not included. Both sides
      # are normalised.
      #
      # @return [Hash{Symbol => Object}] in attribute_names order
      def diff
        seeded = seed
        normalise(@wizard.answers_on_path).reject { |name, value| seeded[name] == value }
      end

      # @return [Boolean]
      def diff?
        !diff.empty?
      end

      # Whether the record changed since it was seeded
      #
      # Compares updated_at only, in UTC to the microsecond. False when
      # nothing is seeded, or when the record has no updated_at now and had
      # none when it was seeded.
      #
      # @param record [#updated_at]
      # @return [Boolean]
      def stale?(record)
        return false unless edit?

        stamp(record.updated_at) != seed_updated_at
      end

      # Remove this changeset's answers and metadata
      #
      # Only this changeset's data: a Redis or Session repository with a
      # state_key keeps its other states. A custom repository that keeps
      # several state_keys under one key must make `delete_state` remove
      # only its own.
      #
      # @return [void]
      def discard!
        state_store.repository.delete_state
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

      def edit_fields
        fields[:edit] || {}
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

      def stamp(time)
        time&.getutc&.iso8601(6)
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
