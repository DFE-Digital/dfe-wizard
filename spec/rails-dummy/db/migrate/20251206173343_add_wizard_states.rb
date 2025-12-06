class AddWizardStates < ActiveRecord::Migration[7.2]
  def change
    create_table :wizard_states do |t|
      t.string :key
      t.string :state_key
      t.jsonb :state
      t.boolean :encrypted

      t.timestamps
    end

    add_index :wizard_states, %i[key]
    add_index :wizard_states, %i[key state_key]
    add_index :wizard_states, %i[state]
  end
end
