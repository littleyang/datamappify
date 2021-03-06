module Datamappify
  module Repository
    module Persistence
      def find(id_or_ids)
        if id_or_ids.is_a?(Array)
          find_many(id_or_ids)
        else
          find_one(id_or_ids)
        end
      end

      def save(entity)
        create_or_update(entity)
      rescue Datamappify::Data::EntityInvalid
        false
      end

      def save!(entity)
        save(entity) || raise(Datamappify::Data::EntityNotSaved)
      end

      def destroy(id_or_entity)
        default_data_class.send :destroy, extract_entity_id(id_or_entity)
      end

      def destroy!(id_or_entity)
        destroy(id_or_entity) || raise(Datamappify::Data::EntityNotDestroyed)
      end

      def method_missing(symbol, *args)
        default_data_class.send symbol, *args
      end

      private

      def find_many(ids)
        ids.map { |id| find_one(id) }
      end

      def find_one(id)
        entity_class.new data_mapping_walker(data_mapping, id)
      end

      def create_or_update(entity)
        raise Datamappify::Data::EntityInvalid.new(entity) if entity.invalid?

        entity.id ? update(entity) : create(entity)
      end

      def create(entity)
        entity_class.new data_mapping_walker(data_mapping, nil, entity.attributes)
      end

      def update(entity)
        entity_class.new data_mapping_walker(data_mapping, entity.id, entity.attributes)
      end

      def data_mapping_walker(data_mapping, id, updated_attributes = nil)
        composed_attributes = {}

        data_mapping.each do |data_class_name, data_fields_mapping|
          id     = find_data_object_id(data_class_name, id)
          values = extract_data_field_values(data_class_name, id, updated_attributes, data_fields_mapping)

          data_fields_with_values = {}

          data_fields_mapping.each_with_index do |(data_field_name, attribute_name), index|
            composed_attributes[attribute_name] = data_fields_with_values[data_field_name] = values[index]
          end

          if id && updated_attributes
            update_data_object(data_class_name, id, data_fields_with_values)
          end
        end

        composed_attributes
      end

      def default_data_class
        data_class(entity_class.name)
      end

      def data_class(data_class_name)
        "Datamappify::Data::#{data_class_name}".constantize
      end

      def foreign_key_field_name
        "#{entity_class.name.underscore}_id"
      end

      def find_data_object_id(data_class_name, id)
        if entity_class.name == data_class_name
          id
        else
          data_class(data_class_name).where(foreign_key_field_name => id).pluck(:id).first
        end
      end

      def extract_data_field_values(data_class_name, id, updated_attributes, data_fields_mapping)
        if updated_attributes.nil?
          find_data_field_values_from_db(data_class_name, id, data_fields_mapping.keys)
        else
          find_data_field_values_from_attributes(updated_attributes, data_fields_mapping.values)
        end
      end

      def find_data_field_values_from_db(data_class_name, id, data_field_names)
        data_class(data_class_name).where(:id => id).pluck(*data_field_names).flatten
      end

      def find_data_field_values_from_attributes(attributes, attribute_names)
        attribute_names.map { |name| attributes[name] }
      end

      def update_data_object(data_class_name, id, data_fields_with_values)
        data_object = data_class(data_class_name).find_or_initialize_by(:id => id)
        data_object.update_attributes data_fields_with_values
      end

      def extract_entity_id(id_or_entity)
        id_or_entity.is_a?(Integer) ? id_or_entity : id_or_entity.id
      end
    end
  end
end
