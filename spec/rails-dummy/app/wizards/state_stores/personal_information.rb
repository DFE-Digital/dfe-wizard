module StateStores
  class PersonalInformation
    include DfE::Wizard::StateStore

    def needs_permission_to_work_or_study?
      !nationalities.intersect?(%w[british irish])
    end

    def right_to_work_or_study?
      right_to_work_or_study == 'yes'
    end

    def nationalities
      Array(read.dig(:steps, :nationality, :nationalities)).compact_blank
    end

    def right_to_work_or_study
      read.dig(:steps, :right_to_work_or_study, :right_to_work_or_study)
    end
  end
end
