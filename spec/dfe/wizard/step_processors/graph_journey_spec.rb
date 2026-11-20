RSpec.describe 'graph.journey' do
  let(:state_store) { CourseChange::StateStore.new }

  # The course questions, with two ways through them: creating a course ends
  # on check answers, editing a saved one on a declaration
  let(:wizard_class) do
    Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course_details

          graph.journey :create do
            graph.check_answers :check_answers, CourseChange::Steps::CheckAnswers
            graph.add_edge from: :start_date, to: :check_answers
          end

          graph.journey :edit do
            graph.add_node :declaration, CourseChange::Steps::Declaration
            graph.add_edge from: :start_date, to: :declaration
            # An edit of the subject asks it, then goes to the declaration
            graph.before_next_step { :declaration if current_step_name == :subject }
            graph.before_previous_step { :subject if current_step_name == :declaration }
          end
        end
      end

      def review_navigation?
        journey == :create
      end

      private

      def course_details(graph)
        graph.root :level
        graph.add_node :level, CourseChange::Steps::Level
        graph.add_node :subject, CourseChange::Steps::Subject
        graph.add_node :start_date, CourseChange::Steps::StartDate
        graph.add_conditional_edge from: :level, when: :further_education?, then: :start_date, else: :subject
        graph.add_edge from: :subject, to: :start_date
      end
    end
  end

  def wizard_for(journey, current_step: :level, current_step_params: {})
    wizard_class.new(state_store:, current_step:, current_step_params:, journey:)
  end

  it 'draws the ending of the journey the wizard was built with' do
    expect(wizard_for(:create).flow_path(:check_answers)).to eq(%i[level subject start_date check_answers])
    expect(wizard_for(:create).find_step(:declaration)).to be_nil

    expect(wizard_for(:edit).flow_path(:declaration)).to eq(%i[level subject start_date declaration])
    expect(wizard_for(:edit).find_step(:check_answers)).to be_nil
    expect(wizard_for(:edit).check_answers_step).to be_nil
  end

  it 'runs only the callbacks of that journey' do
    expect(wizard_for(:create, current_step: :subject).next_step).to eq(:start_date)
    expect(wizard_for(:edit, current_step: :subject).next_step).to eq(:declaration)

    expect(wizard_for(:edit, current_step: :declaration).previous_step).to eq(:subject)
  end

  it 'adds the review callbacks after those of the journey, in the journey that turns them on' do
    state_store.write(level: 'secondary', subject: 'history', start_date: '2026-09')
    change = { level: { level: 'secondary' }, return_to_review: 'level' }

    expect(wizard_for(:create, current_step_params: change).next_step).to eq(:check_answers)
    expect(wizard_for(:edit, current_step_params: change).next_step).to eq(:subject)
  end

  it 'lets a method on the journey turn review navigation on for one journey only' do
    expect(wizard_for(:create).steps_operator.operations_for(:level))
      .to include(DfE::Wizard::Operations::ReviewNavigation)
    expect(wizard_for(:edit).steps_operator.operations_for(:level))
      .to eq([DfE::Wizard::Operations::Validate, DfE::Wizard::Operations::Persist])
  end

  it 'lists every journey the graph declares, and the one drawn, in its metadata' do
    expect(wizard_for(:edit).steps_processor.metadata).to include(journeys: %i[create edit], journey: :edit)
  end

  it 'draws journeys declared in a flow' do
    flow_class = Class.new(wizard_class) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course_details
          graph.flow :endings
        end
      end

      private

      def endings(graph)
        graph.journey(:edit) { graph.add_edge from: :start_date, to: :subject }
        graph.journey(:create) { graph.add_edge from: :start_date, to: :level }
      end
    end

    wizard = flow_class.new(state_store:, current_step: :start_date, journey: 'edit')

    expect(wizard.next_step).to eq(:subject)
  end

  it 'raises when the wizard is built for a journey the graph does not declare' do
    expect { wizard_for(:update) }
      .to raise_error(ArgumentError, 'Build the wizard with journey: one of :create, :edit (got :update)')
  end

  it 'raises when the wizard is built without a journey and the graph declares some' do
    expect { wizard_for(nil) }
      .to raise_error(ArgumentError, 'Build the wizard with journey: one of :create, :edit (got nil)')
  end

  it 'raises when a journey is declared inside another' do
    nested_class = Class.new(wizard_class) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course_details
          graph.journey(:create) { graph.journey(:edit) { nil } }
        end
      end
    end

    expect { nested_class.new(state_store:, journey: :create) }
      .to raise_error(ArgumentError, 'graph.journey :edit is inside graph.journey :create')
  end

  it 'leaves a graph without journeys as it is, whatever the journey' do
    wizard = CourseChange::Wizard.new(state_store:, current_step: :level, journey: :edit)

    expect(wizard.next_step).to eq(:subject)
    expect(wizard.steps_processor.metadata.keys).not_to include(:journeys, :journey)
  end
end
