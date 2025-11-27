class CreateRegisterECTWizardRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :register_ect_wizard_records do |t|
      t.string :trn
      t.string :trs_first_name
      t.string :trs_last_name
      t.string :corrected_name
      t.string :email
      t.string :training_programme
      t.string :working_pattern
      t.string :school_name
      t.string :school_reported_appropriate_body
      t.string :lead_provider_name
      t.date :started_on

      t.timestamps
    end
  end
end
