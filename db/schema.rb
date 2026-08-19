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

ActiveRecord::Schema[7.2].define(version: 2026_08_15_130223) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "name_pt", null: false
    t.integer "difficulty", default: 1
    t.geography "boundary", limit: {srid: 4326, type: "multi_polygon", geographic: true}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "excluded", default: false, null: false
    t.index ["boundary"], name: "index_countries_on_boundary", using: :gist
    t.index ["name"], name: "index_countries_on_name", unique: true
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
    t.bigint "room_round_id"
    t.index ["country_id"], name: "index_game_rounds_on_country_id"
    t.index ["result"], name: "index_game_rounds_on_result"
    t.index ["user_id", "room_round_id"], name: "index_game_rounds_on_user_and_room_round", unique: true, where: "(room_round_id IS NOT NULL)"
    t.index ["user_id"], name: "index_game_rounds_on_user_id"
  end

  create_table "room_players", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "user_id", null: false
    t.integer "score", default: 0, null: false
    t.datetime "joined_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "user_id"], name: "index_room_players_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_room_players_on_room_id"
    t.index ["user_id"], name: "index_room_players_on_user_id"
  end

  create_table "room_rounds", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "country_id", null: false
    t.integer "round_number", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_room_rounds_on_country_id"
    t.index ["room_id", "round_number"], name: "index_room_rounds_on_room_id_and_round_number", unique: true
    t.index ["room_id"], name: "index_room_rounds_on_room_id"
    t.index ["status"], name: "index_room_rounds_on_status"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "host_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "total_rounds", default: 5, null: false
    t.integer "current_round_number", default: 0, null: false
    t.integer "round_duration_seconds", default: 45, null: false
    t.integer "difficulty"
    t.datetime "last_activity_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "current_room_round_id"
    t.index ["code"], name: "index_rooms_on_code", unique: true
    t.index ["current_room_round_id"], name: "index_rooms_on_current_room_round_id"
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["status"], name: "index_rooms_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "game_rounds", "countries"
  add_foreign_key "game_rounds", "room_rounds"
  add_foreign_key "game_rounds", "users"
  add_foreign_key "room_players", "rooms"
  add_foreign_key "room_players", "users"
  add_foreign_key "room_rounds", "countries"
  add_foreign_key "room_rounds", "rooms"
  add_foreign_key "rooms", "room_rounds", column: "current_room_round_id"
  add_foreign_key "rooms", "users", column: "host_id"
end
