class CreateMappings < ActiveRecord::Migration[5.1]
  def change
    create_table :mappings do |t|
      t.string :intercom_convo_id
      t.string :slack_ts_id 
    end
    add_index :mappings, :intercom_convo_id, unique: true
    add_index :mappings, :slack_ts_id, unique: true
  end
end