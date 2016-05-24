class NotificationService
  def initialize(notification)
    @notification = notification
  end

  def send_now
    delete_messages!
    create_messages!

    send_messages
  end

  def enqueue_messages
    delete_messages!
    create_messages!
  end

  private

    attr_accessor :notification

    def message_params(bot_user)
      {
        team_id: bot_user.bot_instance.team_id,
        user:    bot_user.uid,
        text:    notification.content
      }
    end

    def notification_params(bot_user)
      {
        notification: notification,
        scheduled_at: scheduled_at(bot_user)
      }.delete_if { |_, v| v.blank? }
    end

    def delete_messages!
      notification.messages.destroy_all
    end

    def create_messages!
      bot_users = BotUser.where(id: notification.bot_user_ids)
      bot_users.find_each do |bot_user|
        message_object = Messages::Slack.new(message_params(bot_user))
        message_model  = message_object.save_for(bot_user.bot_instance, notification_params(bot_user))

        unless message_model
          Rails.logger.warn "[FAILED NOTIFICATION] Failed to send for Message #{message_model.inspect}"
        end
      end
    end

    def send_messages
      notification.reload.messages.each do |message|
        send_message(message)
      end
    end

    def send_message(message)
      SendMessageJob.perform_async(message.id)
    end

    def scheduled_at(bot_user)
      return nil if notification.scheduled_at.blank?

      notification.scheduled_at.in_time_zone(bot_user.user_attributes['timezone'])
    end
end