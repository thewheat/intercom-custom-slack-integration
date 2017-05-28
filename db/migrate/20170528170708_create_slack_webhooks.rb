class CreateSlackWebhooks < ActiveRecord::Migration[5.1]
  def change
    create_table :slack_webhooks do |t|
      t.string :slack_event_id
    end
    add_index :slack_webhooks, :slack_event_id, unique: true
  end
end