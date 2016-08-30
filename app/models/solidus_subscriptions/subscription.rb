# The subscription class is responsable for grouping together the
# information required for the system to place a subscriptions order on
# behalf of a specific user.
module SolidusSubscriptions
  class Subscription < ActiveRecord::Base
    belongs_to :user, class_name: Spree.user_class
    has_one :line_item, class_name: 'SolidusSubscriptions::LineItem'
    has_many :installments, class_name: 'SolidusSubscriptions::Installment'

    validates :user, presence: :true

    # The subscription state determines the behaviours around when it is
    # processed. Here is a brief description of the states and how they affect
    # the subscription.
    #
    # [active] Default state when created. Subscription can be processed
    # [canceled] The user has ended their subscription. Subscription will not
    #   be processed.
    # [pending_cancellation] The user has ended their subscription, but the
    #   conditions for canceling the subscription have not been met. Subscription
    #   will continue to be processed until the subscription is canceled and
    #   the conditions are met.
    # [inactive] The number of installments has been fulfilled. The subscription
    #   will no longer be processed
    state_machine :state, initial: :active do
      event :cancel do
        transition [:active, :pending_cancellation] => :canceled,
          if: ->(subscription) { subscription.can_be_canceled? }

        transition active: :pending_cancellation
      end

      event :deactivate do
        transition active: :inactive,
          if: ->(subscription) { subscription.can_be_deactivated? }
      end
    end

    # This method determines if a subscription may be canceled. Canceled
    # subcriptions will not be processed. By default subscriptions may always be
    # canceled. If this method is overriden to return false, the subscription
    # will be moved to the :pending_cancellation state until it is canceled
    # again and this condition is true.
    #
    # USE CASE: Subscriptions can only be canceled more than 10 days before they
    # are processed. Override this method to be:
    #
    # def can_be_canceled?
    #   return true if actionable_date.nil?
    #   (actionable_date - 10.days.from_now.to_date) > 0
    # end
    #
    # If a user cancels this subscription less than 10 days before it will
    # be processed the subscription will be bumped into the
    # :pending_cancellation state instead of being canceled. Susbcriptions
    # pending cancellation will still be processed.
    def can_be_canceled?
      true
    end

    # This method determines if a subscription can be deactivated. A deactivated
    # subscription will not be processed. By default a subscription can be
    # deactivated if the number of max_installments defined on the
    # subscription_line_item is equal to the number of installments associated
    # to the subscription. In this case the subscription has been fulfilled and
    # should not be processed again. Subscriptions without a max_installment
    # value cannot be deactivated.
    def can_be_deactivated?
      return false if line_item.max_installments.nil?
      installments.count >= line_item.max_installments
    end
  end
end