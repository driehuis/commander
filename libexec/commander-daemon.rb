# Change this file to be a wrapper around your daemon code.

# Do your post daemonization configuration here
# At minimum you need just the first line (without the block), or a lot
# of strange things might start happening...
DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  # config.trap( 'INT' ) do
  #   # do something clever
  # end
  # config.trap( 'TERM', Proc.new { puts 'Going down' } )
  $0 = "commander (master)"
end

# Sample loop to show process
loop do
  config = DaemonKit::Config.load('commander')
  Commander.run(config)
  sleep config['interval']
end
