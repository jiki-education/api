class Stripe::UpdateSubscription
  include Mandate

  initialize_with :user, :product

  def call
    # Validate user has subscription
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?

    # Validate not same tier
    raise ArgumentError, "Already on #{product} tier" if user.data.membership_type == product

    # Get new price ID
    new_price_id = product == 'premium' ?
      Jiki.config.stripe_premium_price_id :
      Jiki.config.stripe_max_price_id

    # Retrieve subscription from Stripe
    subscription = ::Stripe::Subscription.retrieve(user.data.stripe_subscription_id)

    # Get subscription item ID
    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    # Determine if upgrade or downgrade
    current_tier_value = tier_value(user.data.membership_type)
    new_tier_value = tier_value(product)
    is_upgrade = new_tier_value > current_tier_value

    # Update subscription in Stripe (both immediate)
    updated_subscription = ::Stripe::Subscription.update(
      subscription.id,
      items: [{
        id: subscription_item.id,
        price: new_price_id
      }],
      proration_behavior: is_upgrade ? 'always_invoice' : 'create_prorations'
    )

    # Get the updated subscription item
    updated_subscription_item = updated_subscription.items.data.first
    raise ArgumentError, "Updated subscription has no items" unless updated_subscription_item

    # Handle tier change via dedicated commands for upgrades (sends welcome emails)
    # For downgrades, update membership_type directly (no welcome email)
    if is_upgrade
      case product
      when 'premium' then User::UpgradeToPremium.(user)
      when 'max' then User::UpgradeToMax.(user)
      end
    else
      # Downgrade - set membership_type directly
      user.data.update!(membership_type: product)
    end

    # Update subscription validity period
    user.data.update!(
      subscription_valid_until: Time.zone.at(updated_subscription_item.current_period_end)
    )

    Rails.logger.info("User #{user.id} #{is_upgrade ? 'upgraded' : 'downgraded'} to #{product}")

    {
      success: true,
      tier: product,
      effective_at: 'immediate',
      subscription_valid_until: Time.zone.at(updated_subscription_item.current_period_end)
    }
  end

  private
  def tier_value(tier)
    { 'standard' => 0, 'premium' => 1, 'max' => 2 }[tier]
  end
end
