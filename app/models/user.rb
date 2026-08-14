class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Relacionamentos
  has_many :game_rounds, dependent: :destroy

  # Métodos de estatísticas do usuário
  def total_games
    game_rounds.count
  end

  def correct_games
    game_rounds.correct_guesses.count
  end

  def close_games
    game_rounds.close_guesses.count
  end

  def successful_games
    game_rounds.successful_guesses.count
  end

  def wrong_games
    game_rounds.wrong.count
  end

  # Porcentagem de acertos exatos (dentro do país)
  def accuracy_percentage
    return 0 if total_games.zero?
    (correct_games.to_f / total_games * 100).round(1)
  end

  # Porcentagem de sucesso (acertos + quase)
  def success_percentage
    return 0 if total_games.zero?
    (successful_games.to_f / total_games * 100).round(1)
  end
end
