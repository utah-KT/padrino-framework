module Padrino
  module Reloader
    module Storage
      extend self

      def clear!
        files.each_key do |file|
          remove(file)
          Reloader.remove_feature(file)
        end
        @files = {}
      end

      def remove(name)
        file = files[name] || return
        file[:constants].each{ |constant| Reloader.remove_constant(constant) }
        file[:features].each{ |feature| Reloader.remove_feature(feature) }
        files.delete(name)
      end

      def prepare(name)
        file = remove(name)
        @old_entries ||= {}
        @old_entries[name] = {
          :constants => ObjectSpace.classes,
          :features  => old_features = Set.new($LOADED_FEATURES.dup)
        }
        features = file && file[:features] || []
        features.each{ |feature| Reloader.safe_load(feature, :force => true) }
        Reloader.remove_feature(name) if old_features.include?(name)
      end

      def commit(name)
        entry = {
          :constants => ObjectSpace.new_classes(@old_entries[name][:constants]),
          :features  => Set.new($LOADED_FEATURES) - @old_entries[name][:features] - [name]
        }
        files[name] = entry
        @old_entries.delete(name)
      end

      def rollback(name)
        @rollback_entry = {
          :constants => ObjectSpace.new_classes(@old_entries[name][:constants])
        }
        @rollback_entry[:constants].each do |klass|
          loaded_in_name = files.each do |file, data|
            next if file == name
            break if data[:constants].map(&:to_s).include?(klass.to_s)
          end
          if loaded_in_name
            logger.devel "kclass #{klass}"
            logger.devel "rollback_entry #{@rollback_entry}"
            logger.devel "rollback_entry to_s #{@rollback_entry[:constants].map(&:to_s)}"
            logger.devel "name #{name} files #{files}"
            Reloader.remove_constant(klass)
          end
        end 
        @old_entries.delete(name)
      end

      private

      def files
        @files ||= {}
      end
    end
  end
end
