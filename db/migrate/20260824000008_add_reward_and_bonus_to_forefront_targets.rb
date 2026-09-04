class AddRewardAndBonusToForefrontTargets < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_targets, :reward_type, :string
    add_column :forefront_targets, :reward_value, :decimal, precision: 12, scale: 2
    add_column :forefront_targets, :bonus_type, :string
    add_column :forefront_targets, :bonus_value, :decimal, precision: 12, scale: 2
  end
end
