class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.date :date_of_birth
      t.string :phone
      t.text :bio

      t.string :password_digest
      t.string :api_token
      t.string :secret_key

      t.timestamps

      t.index :email, unique: true
    end
  end
end
