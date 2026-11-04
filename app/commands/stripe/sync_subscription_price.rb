class Stripe::SyncSubscriptionPrice
  include Mandate

  initialize_with :user, :subscription

  # Stores what Stripe will charge on the subscription's next renewal, in the
  # subscription's own currency. Premium prices are multi-currency, so the
  # amount comes from the matching currency_option, not the price's base amount.
  def call
    user.data.update!(
      subscription_amount_in_cents: amount_in_cents,
      subscription_currency: subscription.currency
    )
  end

  private
  def amount_in_cents
    return price.unit_amount if price.currency == subscription.currency

    option = price.currency_options&.[](subscription.currency.to_sym)
    raise ArgumentError, "Price #{price.id} has no #{subscription.currency} amount" unless option&.unit_amount

    option.unit_amount
  end

  # Webhook payloads don't include currency_options, so fetch the price with them.
  memoize
  def price
    price_id = subscription.items.data.first.price.id
    ::Stripe::Price.retrieve({ id: price_id, expand: ["currency_options"] })
  end
end
