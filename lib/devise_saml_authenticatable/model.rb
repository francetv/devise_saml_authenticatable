require 'devise_saml_authenticatable/strategy'
require 'devise_saml_authenticatable/saml_response'

module Devise
  module Models
    module SamlAuthenticatable
      extend ActiveSupport::Concern

      # Need to determine why these need to be included
      included do
        attr_reader :password, :current_password
        attr_accessor :password_confirmation
      end

      def after_saml_authentication(session_index)
        if Devise.saml_session_index_key && self.respond_to?(Devise.saml_session_index_key)
          self.update_attribute(Devise.saml_session_index_key, session_index)
        end
      end

      def authenticatable_salt
        if Devise.saml_session_index_key &&
           self.respond_to?(Devise.saml_session_index_key) &&
           self.send(Devise.saml_session_index_key).present?
          self.send(Devise.saml_session_index_key)
        else
          super
        end
      end

      module ClassMethods
       
       def serialize_from_session(key, salt)
           new salt
       end

       def serialize_into_session(record)
           auth_key = self.authentication_keys.first
           return nil unless record.respond_to?(auth_key)
           [record.class, record.to_hash]
         end


       def authenticate_with_saml(saml_response, relay_state)
          key = Devise.saml_default_user_key
          attributes = saml_response.attributes
          attributes.class.single_value_compatibility = false
          if (Devise.saml_use_subject)
            auth_value = saml_response.name_id
          else
            inv_attr = attribute_map.invert
            auth_value = attributes[inv_attr[key.to_s]]
          end
          auth_value.try(:downcase!) if Devise.case_insensitive_keys.include?(key)

          resource = new

          if Devise.saml_update_user || (resource.new_record? && Devise.saml_create_user)
            set_user_saml_attributes(resource, attributes)
            if (Devise.saml_use_subject)
              resource.send "#{key}=", auth_value
            end
            resource.save!
          end
          resource
        end


        def reset_session_key_for(name_id)
          resource = find_by(Devise.saml_default_user_key => name_id)
          resource.update_attribute(Devise.saml_session_index_key, nil) unless resource.nil?
        end

        def find_for_shibb_authentication(conditions)
          find_for_authentication(conditions)
        end

        def attribute_map
          @attribute_map ||= attribute_map_for_environment
        end

        private

        def set_user_saml_attributes(user,attributes)
          attribute_map.each do |k,v|
            Rails.logger.debug "Setting: #{v}, #{attributes[k]}"
            value = attributes[k].count == 1 ? attributes[k].first : attributes[k]
            user.send "#{v}=", value
          end
        end

        def attribute_map_for_environment
          attribute_map = YAML.load(File.read("#{Rails.root}/config/attribute-map.yml"))
          if attribute_map.has_key?(Rails.env)
            attribute_map[Rails.env]
          else
            attribute_map
          end
        end
      end
    end
  end
end