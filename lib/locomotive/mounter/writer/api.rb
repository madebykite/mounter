module Locomotive
  module Mounter
    module Writer
      module Api

        # Build a singleton instance of the Runner class.
        #
        # @return [ Object ] A singleton instance of the Runner class
        #
        def self.instance
          @@instance ||= Runner.new(:api)
        end

        def self.teardown
          @@instance = nil
        end

        class Runner < Locomotive::Mounter::Writer::Runner

          attr_accessor :uri

          # Call the LocomotiveCMS engine to get a token for
          # the next API calls
          def prepare
            # by default, do not push data (content entries and editable elements)
            self.parameters[:data] ||= false

            ssl_options = self.parameters.select { |k, _| %w(client_pem_file client_pem_password ssl_ca_file).include?(k.to_s) }
            if ssl_options[:client_pem_file]
              begin
                Locomotive::Mounter::EngineApi.set_client_certificate(ssl_options)
              rescue Exception => e
                raise Locomotive::Mounter::ReaderException.new("unable to set client certificate: #{e.message}")
              end
            end

            credentials = self.parameters.select { |k, _| %w(uri email password api_key).include?(k.to_s) }
            self.uri    = credentials[:uri]

            begin
              Locomotive::Mounter::EngineApi.set_token(credentials)
            rescue Exception => e
              raise Locomotive::Mounter::WriterException.new("unable to get an API token: #{e.message}")
            end
          end

          # Ordered list of atomic writers
          #
          # @return [ Array ] List of classes
          #
          def writers
            [SiteWriter, SnippetsWriter, ContentTypesWriter, ContentEntriesWriter, TranslationsWriter, PagesWriter, ThemeAssetsWriter].tap do |_writers|
              # modify the list depending on the parameters
              if self.parameters
                if self.parameters[:data] == false && !(self.parameters[:only].try(:include?, 'content_entries'))
                  _writers.delete(ContentEntriesWriter)
                end

                if self.parameters[:translations] == false && !(self.parameters[:only].try(:include?, 'translations'))
                  _writers.delete(TranslationsWriter)
                end
              end
            end
          end

          # Get the writer to push content assets
          #
          # @return [ Object ] A memoized instance of the content assets writer
          #
          def content_assets_writer
            @content_assets_writer ||= ContentAssetsWriter.new(self.mounting_point, self).tap do |writer|
              writer.prepare
            end
          end

        end

      end
    end
  end
end
