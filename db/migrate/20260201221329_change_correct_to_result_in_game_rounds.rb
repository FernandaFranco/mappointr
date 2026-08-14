class ChangeCorrectToResultInGameRounds < ActiveRecord::Migration[7.2]
  def change
    # Remove a coluna boolean antiga
    remove_column :game_rounds, :correct, :boolean

    # Adiciona nova coluna para enum
    # 0 = correct (dentro do país)
    # 1 = close (até 500km da fronteira)
    # 2 = wrong (mais de 500km)
    add_column :game_rounds, :result, :integer, default: 2, null: false

    # Índice para filtrar por resultado
    add_index :game_rounds, :result
  end
end
