# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170527170708) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ignore_webhooks", force: :cascade do |t|
    t.string "intercom_convo_id"
    t.string "intercom_comment_id"
    t.index ["intercom_comment_id"], name: "index_ignore_webhooks_on_intercom_comment_id", unique: true
    t.index ["intercom_convo_id"], name: "index_ignore_webhooks_on_intercom_convo_id"
  end

  create_table "mappings", force: :cascade do |t|
    t.string "intercom_convo_id"
    t.string "slack_ts_id"
    t.index ["intercom_convo_id"], name: "index_mappings_on_intercom_convo_id", unique: true
    t.index ["slack_ts_id"], name: "index_mappings_on_slack_ts_id", unique: true
  end

  create_table "user_mappings", force: :cascade do |t|
    t.string "intercom_admin_id"
    t.string "slack_user_id"
    t.index ["intercom_admin_id"], name: "index_user_mappings_on_intercom_admin_id", unique: true
    t.index ["slack_user_id"], name: "index_user_mappings_on_slack_user_id", unique: true
  end

end
