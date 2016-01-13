require_relative './analyzer'

class Builder
  def initialize(path, configuration, platform)
    fail 'Empty path provided' if path.to_s == ''
    fail "File (#{path}) not exist" unless File.exist? path

    fail 'No configuration provided' if configuration.to_s == ''
    fail 'No platform provided' if platform.to_s == ''

    @path = path
    @configuration = configuration
    @platform = platform
  end

  def build
    analyzer = Analyzer.new()
    analyzer.analyze(@path)

    build_commands = analyzer.build_commands(@configuration, @platform)

    build_commands.each do |build_command|
      puts
      puts build_command
      puts
      system(build_command)
    end

    output_hash = analyzer.output_hash(@configuration, @platform)
    puts
    puts "output_hash: #{output_hash}"
  end
end
