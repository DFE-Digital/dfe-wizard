Dir[
  File.expand_path(File.join(File.dirname(__FILE__), 'personal_information_wizard/steps/*'))
].each { |f| require f }

class PersonalInformationWizard < DfE::Wizard::Base
  def steps_mapping
    [
      { name_and_date_of_birth: NameAndDateOfBirthStep },
      { nationality: NationalityStep },
      { right_to_work_or_study: RightToWorkOrStudyStep },
      { immigration_status: ImmigrationStatusStep },
      { review: ReviewStep },
    ]
  end

  def steps_processor
    DfE::Wizard::Steps::Graph.draw(self) do |graph|
      graph.start :name_and_date_of_birth
      graph.add_edge :name_and_date_of_birth, to: :nationality

      graph.add_branch(:nationality,
                       when: :needs_permission_to_work_or_study?,
                       then: :right_to_work_or_study,
                       else: :review,
                       label: 'Non-UK/Irish')

      graph.add_branch(
        :right_to_work_or_study,
        when: lambda { |data|
          data.dig(:steps, :right_to_work_or_study, :right_to_work_or_study) == 'yes'
        },
        then: :review,
        else: :immigration_status,
        label: 'Right to work or study?',
      )

      graph.add_edge :immigration_status, to: :review
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(self)
  end

  def logger
    DfE::Wizard::Logger.new(Rails.logger) if Rails.env.local?
  end

  def needs_permission_to_work_or_study?(data)
    nationalities = data.dig(:steps, :nationality, :nationalities)

    !nationalities.intersect?(%w[British Irish])
  end
end

## Controller Named routes
## Multiple controllers:  DfE::Wizard::RouteStrategy::NamedRoutes.new
##
# def new
#  PersonalInformationWizard.new(
#    state_store: PersonalInformationStateStore.new(current_application),
#    current_step: :name_and_date_of_birth
#  )
# end
#
# def create
#  wizard = PersonalInformationWizard.new(
#    state_store: PersonalInformationStateStore.new(current_application),
#    current_step: :name_and_date_of_birth,
#    step_params: params.require(:name_and_date_of_birth_step)
#  )
#
#  if wizard.save
#    redirect_to wizard.next_step_path
#  else
#    render :new
#  end
# end
#
### One Controller dynamic routes: DfE::Wizard::RouteStrategy::Dynamic.new
# before_action :verify_step
#
# def new
#  PersonalInformationWizard.new(
#    state_store:,
#    current_step: params[:step],
#    return_to: params[:return_to]
#  )
# end
#
# def create
#  wizard = PersonalInformationWizard.new(
#    state_store:,
#    current_step: params[:step],
#    step_params: params.require(params[:step]),
#    return_to: params[:return_to]
#  )
#
#  if wizard.save
#    redirect_to wizard.next_step_path
#  else
#    render :new
#  end
# end
#
# def state_store
#  PersonalInformationStateStore.new(current_application)
# end
#
# def verify_step
#  raise NotFound unless wizard.step_names.include?(params[:step])
#
#  # If you're British or Irish can not enter on /immigration-status for example
#  raise NotFound unless wizard.step_processor.valid_for_current_state?(params[:step])
# end
#
## for dynamic routing
## new.html.erb
## <%= render "personal_information_wizard/steps/#{params[:step]}" %>
