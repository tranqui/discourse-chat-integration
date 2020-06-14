# frozen_string_literal: true

module DiscourseChat
  module Provider
    module MattermostProvider
      PROVIDER_NAME = "mattermost".freeze
      PROVIDER_ENABLED_SETTING = :chat_integration_mattermost_enabled
      WEBHOOK_PARAMETERS = [
                          { key: "name", regex: '^\S*$', unique: true },
                          { key: "url", regex: '^\S*$', unique: false },
                          { key: "username", regex: '^.*$', unique: false},
                          { key: "icon_url", regex: '^[\S]*$', unique: false },
                          { key: "excerpt_length", regex: '^\d\d*$', unique: false },
                          { key: "compact_excerpt_length", regex: '^\d\d*$', unique: false }
                       ]
      CHANNEL_PARAMETERS = [
                          { key: "webhook", regex: '^[\S]*$', unique: true,
                            combo_box: true },
                          { key: "identifier", regex: '^[@#]\S*$', unique: true }
                       ]

      def self.send_via_webhook(url, message)
        uri = URI(url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = message.to_json
        response = http.request(req)

        unless response.kind_of? Net::HTTPSuccess
          if response.body.include? "Couldn't find the channel"
            error_key = 'chat_integration.provider.mattermost.errors.channel_not_found'
          else
            error_key = nil
          end
          raise ::DiscourseChat::ProviderError.new info: { error_key: error_key, request: req.body, response_code: response.code, response_body: response.body }
        end

      end

      def self.mattermost_message(post, channel, username, icon_url, excerpt_length, style, specify_category)
        display_name = "@#{post.user.username}"
        full_name = post.user.name || ""

        if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0) && (full_name.strip.gsub(' ', '').casecmp(post.user.username) != 0)
          display_name = "#{full_name} @#{post.user.username}"
        end

        topic = post.topic

        category = ''
        if topic.category&.uncategorized?
          category = "#{I18n.t('uncategorized_category_name')}"
        elsif topic.category
          category = (topic.category.parent_category) ? "#{topic.category.parent_category.name}/#{topic.category.name}" : "#{topic.category.name}"
          category = "[#{category}](#{Discourse.base_url}/c/#{topic.category.slug_for_url})"
        else
          category = "group message"
        end

        message = {
          channel: channel,
          username: username,
          icon_url: icon_url
        }

        text = "#{post.excerpt(excerpt_length, text_entities: true, strip_links: true, remap_emoji: true)}"
        if text.length > excerpt_length
          text = "#{text} _[(Read more)](#{post.full_url})_"
        end
        text = text.gsub("@", "@[]()")

        title_suffix = specify_category ? " in #{category}" : ""
        title = "[#{topic.title}](#{post.full_url})#{title_suffix}"
        author_link = "#{Discourse.base_url}/u/#{post.user.username}"

        summary = {
          fallback: "#{topic.title} - #{display_name}",
          color: topic.category ? "##{topic.category.color}" : nil
          #{topic.tags.present? ? topic.tags.map(&:name).join(', ') : ''}",
        }

        if style == "long"
          text = text.gsub("\n", "\n\n")
          summary["author_name"] = display_name
          summary["author_icon"] = post.user.small_avatar_url
          action = post.is_first_post? ? "created" : "replied to"
          summary["title"] = "#{action} #{title}:"
        elsif style == "medium"
          text = text.gsub(/\s+/, ' ')
          author = "[![#{display_name}'s avatar](#{post.user.small_avatar_url} =16x16)#{display_name}](#{author_link})"
          action = post.is_first_post? ? "created" : "on"
          text = "_#{author} #{action} #{title}:_ \n\n#{text}"
        elsif style == "short"
          text = text.gsub(/\s+/, ' ')
          author = "[#{display_name}](#{author_link})"
          action = post.is_first_post? ? "created" : "on"
          text = "_#{author} #{action} #{title}:_ #{text}"
        else
          error_key = 'chat_integration.provider.mattermost.errors.style_not_found'
          raise ::DiscourseChat::ProviderError.new info: { error_key: error_key, style: style }
        end

        if style == "short"
          message["text"] = text
        else
          summary["text"] = text
          message["attachments"] = [summary]
        end

        message
      end

      def self.trigger_notification(post, channel, style="medium", specify_category=true)
        webhook_name = channel.data['webhook']

        if webhook_name.blank?
          url = SiteSetting.chat_integration_mattermost_webhook_url
          username = SiteSetting.title || "Discourse"
          if style == "long"
            excerpt_length = SiteSetting.chat_integration_mattermost_excerpt_length
          else
            excerpt_length = SiteSetting.chat_integration_mattermost_compact_excerpt_length
          end
          icon_url = nil
        else
          webhooks = DiscourseChat::Webhook.with_provider(PROVIDER_NAME)
          webhook = webhooks.with_data_value('name', webhook_name).first
          if webhook.nil?
            error_key = 'chat_integration.provider.mattermost.errors.webhook_not_found'
            raise ::DiscourseChat::ProviderError.new info: { error_key: error_key, webhook: webhook_name }
          end

          url = webhook.data['url']
          username = webhook.data['username'] || SiteSetting.title || "Discourse"
          icon_url = webhook.data['icon_url']

          if style == "long"
            excerpt_length = webhook.data['excerpt_length'] || SiteSetting.chat_integration_mattermost_excerpt_length
          else
            excerpt_length = webhook.data['compact_excerpt_length'] || SiteSetting.chat_integration_mattermost_compact_excerpt_length
          end
          excerpt_length = Integer(excerpt_length)
        end

        if icon_url.blank?
          icon_url =
            if SiteSetting.chat_integration_mattermost_icon_url.present?
              UrlHelper.absolute(SiteSetting.chat_integration_mattermost_icon_url)
            elsif (small_url = (SiteSetting.try(:site_logo_small_url) || SiteSetting.logo_small_url)).present?
              UrlHelper.absolute(small_url)
            end
        end

        channel_id = channel.data['identifier']
        message = mattermost_message(post, channel_id, username, icon_url, excerpt_length, style, specify_category)

        self.send_via_webhook(url, message)
      end

    end
  end
end

require_relative "mattermost_command_controller.rb"
