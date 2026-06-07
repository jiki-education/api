class Stripe::DetermineSubscriptionDetails
  def self.price_id_for(interval)
    price_map[interval] || raise(ArgumentError, "Unknown interval: #{interval}")
  end

  def self.interval_for_price_id(price_id)
    price_map.key(price_id) || raise(
      ArgumentError,
      "Unknown Stripe price ID: #{price_id}. Expected one of: #{price_map.values.join(', ')}"
    )
  end

  def self.price_map
    {
      'monthly' => Jiki.config.stripe_premium_monthly_price_id,
      'annual' => Jiki.config.stripe_premium_annual_price_id
    }
  end
end
