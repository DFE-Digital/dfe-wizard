class AddCourses < ActiveRecord::Migration[7.2]
  def change
    create_table :courses do |t|
      t.string :course_code, null: false
      t.string :provider_code, null: false
      t.integer :recruitment_cycle_year, null: false

      t.json :a_level_subject_requirements, default: []

      t.boolean :accept_pending_a_level
      t.boolean :accept_a_level_equivalency
      t.text :additional_a_level_equivalencies

      t.timestamps
    end

    add_index :courses, %i[provider_code recruitment_cycle_year course_code],
              unique: true,
              name: 'index_courses_on_provider_cycle_code'
  end
end
