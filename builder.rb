require_relative './analyzer'
require_relative './common_constants'

class Builder
  def initialize(path, configuration, platform, project_type_filter=nil)
    raise 'Empty path provided' if path.to_s == ''
    raise "File (#{path}) not exist" unless File.exist? path

    raise 'No configuration provided' if configuration.to_s == ''
    raise 'No platform provided' if platform.to_s == ''

    raise 'project_type_filter should be an Array of Strings' if project_type_filter && !project_type_filter.is_a?(Array)

    @path = path
    @configuration = configuration
    @platform = platform
    @project_type_filter = project_type_filter || [Api::IOS, Api::TVOS, Api::ANDROID, Api::MAC]

    @analyzer = Analyzer.new
    @analyzer.analyze(@path)
  end

  def build
    build_commands = @analyzer.build_commands(@configuration, @platform, @project_type_filter)
    if build_commands.empty?
      # No iOS or Android application found to build
      # Switching to framework building
      build_commands << @analyzer.build_solution_command(@configuration, @platform)
    end

    build_commands.each do |build_command|
      puts
      puts "\e[34m#{build_command}\e[0m"
      puts

      raise 'Build failed' unless system(build_command.join(' '))
    end

    @generated_files = @analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def build_solution
    build_command = @analyzer.build_solution_command(@configuration, @platform)

    puts
    puts "\e[34m#{build_command}\e[0m"
    puts

    raise 'Build failed' unless system(build_command.join(' '))

    @generated_files = @analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def build_test
    test_commands, errors = @analyzer.build_test_commands(@configuration, @platform, @project_type_filter)

    if test_commands.nil? || test_commands.empty?
      errors = ['Failed to create test command'] if errors.empty?
      raise errors.join("\n")
    end

    test_commands.each do |test_command|
      puts
      puts "\e[34m#{test_command}\e[0m"
      puts

      raise 'Test failed' unless system(test_command.join(' '))
    end

    @generated_files = @analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def run_nunit_tests(options = nil)
    test_commands, errors = @analyzer.nunit_test_commands(@configuration, @platform, options)

    if test_commands.nil? || test_commands.empty?
      errors = ['Failed to create test command'] if errors.empty?
      raise errors.join("\n")
    end

    test_commands.each do |test_command|
      puts
      puts "\e[34m#{test_command}\e[0m"
      puts

      raise 'Test failed' unless system(test_command.join(' '))
    end
  end

  def run_nunit_lite_tests
    dir = Dir.mktmpdir
    begin
      touch_unit_server = get_touch_unit_server(dir)

      logfile = 'tests.log'
      test_commands, errors = @analyzer.nunit_light_test_commands(@configuration, @platform, touch_unit_server, logfile)

      if test_commands.nil? || test_commands.empty?
        errors = ['Failed to create test command'] if errors.empty?
        raise errors.join("\n")
      end

      app_file = nil
      test_commands.each do |test_command|
        puts
        puts "\e[34m#{test_command}\e[0m"
        puts

        command = test_command.join(' ')
        command.sub! '--launchsim', "--launchsim #{app_file}" if command.include? touch_unit_server and !app_file.nil?

        raise 'Test failed' unless system(command)

        if command.include? 'mdtool'
          @generated_files = @analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
          @generated_files.each do |_, project_output|
            app_file = project_output[:app] if project_output[:api] == Api::IOS and project_output[:app]
          end
        end
      end

      results = process_touch_unit_logs(logfile)

      # remove logs file
      FileUtils.remove_entry logfile

      raise 'Test failed' if results['Failed'] != '0'
    rescue => ex
      error_with_message(ex.inspect.to_s)
      error_with_message('--- Stack trace: ---')
      error_with_message(ex.backtrace.to_s)
      exit(1)
    ensure
      FileUtils.remove_entry dir
    end
  end

  def generated_files
    @generated_files
  end

  private

  def get_touch_unit_server(directory)
    # clone Touch.Unit
    `git clone git@github.com:spouliot/Touch.Unit.git #{directory}`
    server_project_path = File.join(directory, 'Touch.Server/Touch.Server.csproj')

    # build Touch.Unit server
    puts `xbuild #{server_project_path}`

    exe_files = []
    Find.find(File.join(directory, 'Touch.Server/bin/Debug/')) do |path|
      exe_files << path if path =~ /.*\.exe$/
    end

    touch_unit_server = exe_files.first
    raise 'Touch.Server.exe was not found' unless touch_unit_server

    touch_unit_server
  end

  def process_touch_unit_logs(logs_path)
    results = Hash.new
    if File.exist?(logs_path)
      File.open(logs_path, "r") do |f|
        f.each_line do |line|
          puts line
          if line.start_with?('Tests run')
            line.gsub (/[a-zA-z]*: [0-9]*/) { |s|
              s.delete!(' ')
              test_result = s.split(/:/)
              results[test_result.first] = test_result.last
            }
          end
        end
      end
    else
      raise 'Cant find test logs file'
    end

    results
  end
end
