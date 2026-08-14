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

ActiveRecord::Schema[7.2].define(version: 2026_02_02_014935) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "name_pt", null: false
    t.integer "difficulty", default: 1
    t.geography "boundary", limit: { srid: 4326, type: "multi_polygon", geographic: true }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "excluded", default: false, null: false
    t.index [ "boundary" ], name: "index_countries_on_boundary", using: :gist
    t.index [ "name" ], name: "index_countries_on_name", unique: true
  end

  create_table "game_rounds", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "country_id", null: false
    t.decimal "guessed_lat"
    t.decimal "guessed_lng"
    t.integer "distance_km"
    t.integer "time_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "result", default: 2, null: false
    t.index [ "country_id" ], name: "index_game_rounds_on_country_id"
    t.index [ "result" ], name: "index_game_rounds_on_result"
    t.index [ "user_id" ], name: "index_game_rounds_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "email" ], name: "index_users_on_email", unique: true
    t.index [ "reset_password_token" ], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "game_rounds", "countries"
  add_foreign_key "game_rounds", "users"
end
