# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_12_06_173343) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'courses', force: :cascade do |t|
    t.string 'course_code', null: false
    t.string 'provider_code', null: false
    t.integer 'recruitment_cycle_year', null: false
    t.json 'a_level_subject_requirements', default: []
    t.boolean 'accept_pending_a_level'
    t.boolean 'accept_a_level_equivalency'
    t.text 'additional_a_level_equivalencies'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[provider_code recruitment_cycle_year course_code], name: 'index_courses_on_provider_cycle_code',
                                                                  unique: true
  end

  create_table 'register_ect_wizard_records', force: :cascade do |t|
    t.string 'trn'
    t.string 'trs_first_name'
    t.string 'trs_last_name'
    t.string 'corrected_name'
    t.string 'email'
    t.string 'training_programme'
    t.string 'working_pattern'
    t.string 'school_name'
    t.string 'school_reported_appropriate_body'
    t.string 'lead_provider_name'
    t.date 'started_on'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email', null: false
    t.string 'first_name'
    t.string 'last_name'
    t.date 'date_of_birth'
    t.string 'phone'
    t.text 'bio'
    t.string 'password_digest'
    t.string 'api_token'
    t.string 'secret_key'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['email'], name: 'index_users_on_email', unique: true
  end

  create_table 'wizard_states', force: :cascade do |t|
    t.string 'key'
    t.string 'state_key'
    t.jsonb 'state'
    t.boolean 'encrypted'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[key state_key], name: 'index_wizard_states_on_key_and_state_key'
    t.index ['key'], name: 'index_wizard_states_on_key'
    t.index ['state'], name: 'index_wizard_states_on_state'
  end
end
