module Steps
  module Courses
    class Subjects
      include DfE::Wizard::Step

      attribute :main_subject, :string
      attribute :second_subject, :string
      validates :main_subject, presence: true

      Option = Struct.new(:id, :name, keyword_init: true)

      def self.permitted_params
        %i[main_subject second_subject]
      end

      def primary_subjects
        PRIMARY_SUBJECTS.map { |name, id| Option.new(name:, id:) }
      end

      def secondary_subjects
        SECONDARY_SUBJECTS.map { |name, id| Option.new(name:, id:) }
      end

      PRIMARY_SUBJECTS = {
        'Primary' => '00',
        'Primary with English' => '01',
        'Primary with geography and history' => '02',
        'Primary with mathematics' => '03',
        'Primary with modern languages' => '04',
        'Primary with physical education' => '06',
        'Primary with science' => '07',
      }.freeze

      SECONDARY_SUBJECTS = {
        'Ancient Greek' => 'A1',
        'Ancient Hebrew' => 'A2',
        'Art and design' => 'W1',
        'Science' => 'F0',
        'Biology' => 'C1',
        'Business studies' => '08',
        'Chemistry' => 'F1',
        'Citizenship' => '09',
        'Classics' => 'Q8',
        'Communication and media studies' => 'P3',
        'Computing' => '11',
        'Dance' => '12',
        'Design and technology' => 'DT',
        'Drama' => '13',
        'Economics' => 'L1',
        'English' => 'Q3',
        'French' => '15',
        'Geography' => 'F8',
        'German' => '17',
        'Health and social care' => 'L5',
        'History' => 'V1',
        'Latin' => 'A0',
        'Mathematics' => 'G1',
        'Music' => 'W3',
        'Philosophy' => 'P1',
        'Physical education' => 'C6',
        'Physical education with an EBacc subject' => 'C7',
        'Physics' => 'F3',
        'Psychology' => 'C8',
        'Religious education' => 'V6',
        'Social sciences' => '14',
        'Spanish' => '22',
      }.freeze
    end
  end
end
