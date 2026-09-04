class AddRenewalAndReclaimRewardToForefrontProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :forefront_products, :renewal_reward_percentage, :decimal, precision: 5, scale: 2
    add_column :forefront_products, :reclaim_reward_percentage, :decimal, precision: 5, scale: 2
  end
end
