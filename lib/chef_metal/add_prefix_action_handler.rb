require 'chef_metal/action_handler'

module ChefMetal
  class AddPrefixActionHandler
    extend Forwardable

    def initialize(action_handler, prefix)
      @action_handler = action_handler
      @prefix = prefix
    end

    attr_reader :action_handler
    attr_reader :prefix

    def_delegators :@action_handler, :should_perform_actions, :updated!, :debug_name, :open_stream
    # TODO remove this as soon as HUMANLY POSSIBLE (looking at you, chef-metal-fog)
    def_delegators :@action_handler, :new_resource

    def performed_action(description)
      action_handler.performed_action(Array(description).map { |d| "#{prefix}#{d}" })
    end

    def perform_action(description, &block)
      action_handler.perform_action(Array(description).map { |d| "#{prefix}#{d}" }, &block)
    end
  end
end
