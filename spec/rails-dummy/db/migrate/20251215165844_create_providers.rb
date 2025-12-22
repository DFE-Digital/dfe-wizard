class CreateProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :providers do |t|
      t.string :name
      t.string :code
      t.integer :recruitment_cycle_year

      t.timestamps
    end
  end
end
