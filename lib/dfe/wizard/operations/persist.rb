module DfE
  module Wizard
    module Operations
      # Persists a step's data to the repository
      #
      # Writes the step's serializable_data to the repository via write_data.
      # Always returns { success: true } (no validation).
      #
      # The Persist operation assumes data has been validated already.
      # It persists whatever data is present, even if incomplete.
      #
      # @example
      #   step = PersonalDetailsStep.new(first_name: 'John', last_name: 'Doe')
      #   persister = Persist.new(repository, step)
      #   result = persister.execute
      #   # => { success: true }
      #   # repository now contains { first_name: 'John', last_name: 'Doe' }
      #
      # @example Persists even with nil values
      #   step = PersonalDetailsStep.new(first_name: 'John', last_name: nil)
      #   persister = Persist.new(repository, step)
      #   persister.execute
      #   # repository contains { first_name: 'John', last_name: nil }
      class Persist
        # Initialize persister
        #
        # @param repository [Object] The repository to persist to
        # @param step_object [DfE::Wizard::Step] The step whose data to persist
        #
        # @example
        #   persister = Persist.new(my_repo, my_step)
        def initialize(repository:, step:)
          @repository = repository
          @step = step
        end

        # Execute persistence
        #
        # Writes the step's serializable_data to the repository.
        #
        # @example
        #   result = persister.execute
        #   # => { success: true }
        #
        # @return [Hash] Always returns { success: true }
        def execute
          @repository.write(@step.serializable_data)

          { success: true }
        end

        # Rollback (no-op for persistence)
        #
        # Once data is written, rollback cannot undo it (would need
        # a transaction-like system). For now, rollback is a no-op.
        #
        # @return [void]
        def rollback
          # No-op: persistence is write-only
        end
      end
    end
  end
end
