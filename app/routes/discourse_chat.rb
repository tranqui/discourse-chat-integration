# frozen_string_literal: true

require_dependency 'admin_constraint'

module DiscourseChat
  AdminEngine.routes.draw do
    get "" => "chat#respond"
    get '/providers' => "chat#list_providers"
    post '/test' => "chat#test"

    get '/channels' => "chat#list_channels"
    post '/channels' => "chat#create_channel"
    put '/channels/:id' => "chat#update_channel"
    delete '/channels/:id' => "chat#destroy_channel"

    post '/rules' => "chat#create_rule"
    put '/rules/:id' => "chat#update_rule"
    delete '/rules/:id' => "chat#destroy_rule"

    get '/webhooks' => "chat#list_webhooks"
    post '/webhooks' => "chat#create_webhook"
    put '/webhooks/:id' => "chat#update_webhook"
    delete '/webhooks/:id' => "chat#destroy_webhook"

    get "/:provider" => "chat#respond"
  end

  PublicEngine.routes.draw do
    get '/:secret' => "public#post_transcript"
  end
end
