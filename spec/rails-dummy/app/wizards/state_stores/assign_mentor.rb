module StateStores
  class AssignMentor
    include DfE::Wizard::StateStore

    def lead_provider_will_not_provide?
      lp_will_provide == 'no'
    end

   # def assign_attributes(wizard)
   #  wizard.step_metadata.each do |step_id, step_klass|
   #   step_klass.attribute_names.map(&:to_sym) do ||
   #     step_attributes = step_klass.attributes
   #     step_attributes.each do |step_attribute|
   #       define_method(step_attribute) do
   #         read.dig(:steps, step_id, step_attribute)
   #       end
   #     end
   #   end
   # end

    # the above to avoid doing this
    def lp_will_provide
      read.dig(:steps, :can_receive_mentor_training, :lp_will_provide)
    end
  end
end
