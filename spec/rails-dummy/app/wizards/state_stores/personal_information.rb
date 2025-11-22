module StateStores
  class PersonalInformation
    include DfE::Wizard::StateStore

    def needs_permission_to_work_or_study?
      !Array(nationalities).intersect?(%w[british irish])
    end

    def right_to_work_or_study?
      right_to_work_or_study == 'yes'
    end
  end
end
