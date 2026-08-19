class AddRoomRoundToGameRounds < ActiveRecord::Migration[7.2]
  def change
    add_reference :game_rounds, :room_round, null: true, foreign_key: true, index: false

    # Um jogador só pode ter uma jogada por rodada de sala (evita corrida de
    # duplo clique criando duas jogadas). Índice parcial: não afeta jogadas
    # solo, onde room_round_id é sempre nil.
    add_index :game_rounds, [ :user_id, :room_round_id ], unique: true,
              where: "room_round_id IS NOT NULL",
              name: "index_game_rounds_on_user_and_room_round"
  end
end
