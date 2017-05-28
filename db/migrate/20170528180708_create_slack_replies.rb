class CreateSlackReplies < ActiveRecord::Migration[5.1]
  def change
    create_table :slack_replies do |t|
      t.string :intercom_admin_id
      t.string :slack_thread_id
      t.string :slack_text
	  t.timestamps
    end
    
    add_index :slack_replies, :intercom_admin_id
    add_index :slack_replies, :slack_thread_id
  end
end