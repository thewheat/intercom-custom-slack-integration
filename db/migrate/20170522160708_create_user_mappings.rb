class CreateUserMappings < ActiveRecord::Migration[5.1]
  def change
    create_table :user_mappings do |t|
      t.string :intercom_admin_id
      t.string :slack_user_id
    end
    add_index :user_mappings, :intercom_admin_id, unique: true
    add_index :user_mappings, :slack_user_id, unique: true
  end
end