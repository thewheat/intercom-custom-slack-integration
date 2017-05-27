class CreateIgnoreWebhooks < ActiveRecord::Migration[5.1]
  def change
    create_table :ignore_webhooks do |t|
      t.string :intercom_convo_id
      t.string :intercom_comment_id
    end
    add_index :ignore_webhooks, :intercom_convo_id
    add_index :ignore_webhooks, :intercom_comment_id, unique: true
  end
end