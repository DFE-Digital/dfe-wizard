class CreateStudySites < ActiveRecord::Migration[7.2]
  def change
    create_table :study_sites do |t|
      t.string :name
      t.references :provider
      t.timestamps
    end
  end
end
