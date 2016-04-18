class Commander < ActiveResource::Base

  def self.running
    @running ||= []
  end

  def self.command_shorten(command)
    desc = command.dup
    desc.gsub!('/usr/bin/pfexec ', '')
    desc.gsub!(/rsync .* ([\w@.]+:\/)/) { 'rsync ' + $1 }
    desc.gsub!(/\s+/, ' ')
    desc = desc.length > 60 ? desc[0,56] + "..." : desc
  end

  def self.run(config)
    self.site = config['url']
    self.user = config['user']
    self.password = config['pass']
    self.element_name = "command"
    self.format = :xml

    begin
      self.find(:all, :conditions => { :exitstatus => nil}).each do | item |
        unless running.include? item.id
          running.push item.id
          pid = Process.fork {
            Process.fork {
              $0 = "commander (worker #{item.id}) #{command_shorten item.command}"
              output=`#{item.command}`
              item.exitstatus = $?.exitstatus
              item.output = output
              saved = false
              retrytime=2
              until saved
                begin
                  saved = item.save
                rescue StandardError => e
                    DaemonKit.logger.info("unknown error on save item #{item.id}: #{e}")
                end
                if retrytime < 14400
                  retrytime = retrytime * 2
                else
                  DaemonKit.logger.info("Giving up on item #{item.id}") unless saved
                  saved=true
                end
                DaemonKit.logger.info("Save status #{item.exitstatus} for pid #{pid} item #{item.id} failed, retrying") unless saved
                sleep retrytime unless saved
              end
            }
            exit 0
          }
          DaemonKit.logger.info("Started process #{pid} for item #{item.id}: #{item.command}")
          Process.detach pid
        end
      end
    rescue Errno::ECONNREFUSED
      DaemonKit.logger.info("Connection refused")
      sleep config['interval']
      retry
    rescue ActiveResource::ServerError => e
      DaemonKit.logger.info("Server error: #{e.message}")
      sleep config['interval']
      retry
    rescue ActiveResource::ResourceNotFound
      DaemonKit.logger.info("404! It seems you are not pointing me to a compatible REST service")
      sleep config['interval']
      retry
    rescue ActiveResource::TimeoutError
      DaemonKit.logger.info("Timed out, will try again")
      sleep config['interval']
      retry
    rescue StandardError => e
      DaemonKit.logger.info("Unknown error: #{e.message}")
      sleep config['interval']
      retry
    end
  end
end
