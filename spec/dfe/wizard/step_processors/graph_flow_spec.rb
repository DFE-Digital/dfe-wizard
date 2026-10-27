RSpec.describe 'graph.flow' do
  let(:state_store) { CourseChange::StateStore.new }

  # Creating a course: the course questions, then check answers
  let(:create_wizard_class) do
    Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course_details
          graph.check_answers :check_answers, CourseChange::Steps::CheckAnswers
          graph.add_edge from: :start_date, to: :check_answers
        end
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

  # Editing a saved course: the same questions, then a confirm page
  let(:edit_wizard_class) do
    Class.new(create_wizard_class) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course_details
          graph.add_node :declaration, CourseChange::Steps::Declaration
          graph.add_edge from: :start_date, to: :declaration
        end
      end
    end
  end

  it 'draws the questions of a flow that two wizards share, each with its own ending' do
    create_wizard = create_wizard_class.new(state_store:)
    edit_wizard = edit_wizard_class.new(state_store:)

    expect(create_wizard.flow_path(:check_answers)).to eq(%i[level subject start_date check_answers])
    expect(edit_wizard.flow_path(:declaration)).to eq(%i[level subject start_date declaration])
    expect(edit_wizard.find_step(:check_answers)).to be_nil
  end

  it 'draws a flow that draws another flow' do
    wizard_class = Class.new(create_wizard_class) do
      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :course
        end
      end

      private

      def course(graph)
        graph.flow :course_details
        graph.check_answers :check_answers, CourseChange::Steps::CheckAnswers
        graph.add_edge from: :start_date, to: :check_answers
      end
    end

    expect(wizard_class.new(state_store:).flow_path(:check_answers)).to eq(%i[level subject start_date check_answers])
  end

  it 'raises when the wizard has no such flow' do
    wizard_class = Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.flow :unknown
        end
      end
    end

    expect { wizard_class.new(state_store:).steps_processor }.to raise_error(NameError, /unknown/)
  end
end
