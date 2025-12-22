module Steps
  module Courses
    class Level
      include DfE::Wizard::Step

      attribute :level, :string
      attribute :send, :string

      validates :level, :send, presence: true

      def self.permitted_params
        %i[level send]
      end

      LEVEL_OPTIONS = {
        primary: 'Primary',
        secondary: 'Secondary',
        further_education: 'Further education',
      }.freeze

      SEND_OPTIONS = {
        yes: 'Yes',
        no: 'No',
      }.freeze

      Option = Struct.new(:id, :name, keyword_init: true)

      def level_options
        LEVEL_OPTIONS.map { |id, name| Option.new(id:, name:) }
      end

      def send_options
        SEND_OPTIONS.map { |id, name| Option.new(id:, name:) }
      end
    end
  end
end
